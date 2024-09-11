const std = @import("std");
const builtin = std.builtin;
const database = @import("database.zig");
const log = std.log;
const math = @import("math.zig");
const mem = std.mem;
const net = std.net;
const posix = std.posix;
const t = std.testing;
const assert = @import("assert.zig").assert;
const Connection = net.Server.Connection;
const Thread = std.Thread;

pub const Port = 2000;
pub const db_controller = @import("server/db_controller.zig");

const ThreadData = struct {
    conn: Connection,
    db: database.DbRef,
    chatroom: *ChatroomView,
};

pub fn run() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, Port);
    var s = try addr.listen(.{});
    defer s.deinit();

    var db = try database.init_db();

    log.info("[server] listening on {}", .{addr});
    defer log.info("[server] shutting down", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var chatroom = Chatroom{
        .lock = Thread.RwLock{},
        .allocator = allocator,
        .messages = std.ArrayList([]u8).init(allocator),
        .views = .{null} ** 8,
    };

    while (true) {
        const conn = try s.accept();
        _ = try Thread.spawn(.{}, handle, .{ThreadData{
            .conn = conn,
            .db = database.DbRef{ .db = &db, .mutex = Thread.Mutex{} },
            .chatroom = chatroom.new_view(),
        }});
    }
}

fn handle(data: ThreadData) void {
    log.info("[handler {}] accepted connection", .{data.conn.address});
    defer log.info("[handler {}] connection closed", .{data.conn.address});

    var conn = data.conn;
    var db = data.db;
    const writer = conn.stream.writer();

    log.debug("[handler {}] performing handshake", .{conn.address});

    const handshake = connection_handshake(&conn) catch |err| {
        log.err("[handler {}] handshake error: {}", .{ conn.address, err });

        writer.print("err\n{}", .{err}) catch {};
        conn.stream.close();

        return;
    };

    log.debug("[handler {}] checking if game exists", .{conn.address});

    const game_exists = db_controller.game_exists(&db, handshake.game_id) catch |err| {
        log.err("[handler {}] db error: {}", .{ conn.address, err });

        writer.print("err\n{}", .{err}) catch {};
        conn.stream.close();

        return;
    };

    if (!game_exists) {
        log.debug("[handler {}] game does not exist", .{conn.address});

        writer.writeAll("err\nGame does not exist") catch {};
        conn.stream.close();

        return;
    }

    log.debug("[handler {}] checking if player is in game", .{conn.address});

    const player_in_game = db_controller.player_in_game(&db, handshake.game_id, handshake.player_id) catch |err| {
        log.err("[handler {}] db error: {}", .{ conn.address, err });

        writer.print("err\n{}", .{err}) catch {};
        conn.stream.close();

        return;
    };

    if (!player_in_game) {
        log.debug("[handler {}] player does not play in this game", .{conn.address});

        writer.writeAll("err\nPlayer not in game") catch {};
        conn.stream.close();

        return;
    }

    conn.stream.writeAll("ready\n") catch |err| {
        log.err("[handler {}] write error: {}", .{ data.conn.address, err });
        conn.stream.close();
        return;
    };

    connection_loop(data);
}

const HandshakePacket = struct {
    player_id: u64,
    game_id: u64,
};

fn connection_handshake(conn: *const Connection) !HandshakePacket {
    const reader = conn.stream.reader();

    var buf: [16]u8 = undefined;

    for (0..buf.len) |i| {
        const c = try reader.readByte();
        buf[i] = c;
    }

    return .{
        .player_id = math.u8s_to_u64(buf[0..8]),
        .game_id = math.u8s_to_u64(buf[8..]),
    };
}

const ServerState = enum {
    listening,
    expecting_msg,
};

const ChatroomView = struct {
    chatroom: *Chatroom,
    new_messages: u32,

    fn view_i_latest_msg(self: *ChatroomView, i: usize, buf: []u8) []u8 {
        return self.chatroom.view_i_latest_msg(i, buf, self);
    }
};

const Chatroom = struct {
    lock: Thread.RwLock,
    allocator: mem.Allocator,
    messages: std.ArrayList([]u8),
    views: [8]?ChatroomView,

    fn deinit(self: *Chatroom) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg);
        }
        self.messages.deinit();
    }

    fn new_msg(self: *Chatroom, msg: []u8) void {
        self.lock.lock();
        defer self.lock.unlock();

        const m = self.allocator.alloc(u8, msg.len) catch unreachable;
        mem.copyForwards(u8, m, msg);

        self.messages.append(m) catch unreachable;

        for (&self.views) |*view| {
            if (view.* == null) {
                continue;
            }
            _ = @atomicRmw(u32, &view.*.?.new_messages, builtin.AtomicRmwOp.Add, 1, builtin.AtomicOrder.release);
        }
    }

    fn view_i_latest_msg(self: *Chatroom, i: usize, buf: []u8, view: *ChatroomView) []u8 {
        self.lock.lockShared();
        defer self.lock.unlockShared();

        if (view.new_messages > 0) {
            _ = @atomicRmw(u32, &view.new_messages, builtin.AtomicRmwOp.Sub, 1, builtin.AtomicOrder.release);
        }

        const idx = self.messages.items.len - 1 - i;
        assert(idx >= 0, "Out of bounds");
        assert(self.messages.items[idx].len <= buf.len, "Buffer too small");

        mem.copyForwards(u8, buf, self.messages.items[idx]);
        return buf[0..self.messages.items[idx].len];
    }

    fn new_view(self: *Chatroom) *ChatroomView {
        var idx: usize = 999;
        for (0..self.views.len) |i| {
            if (self.views[i] == null) {
                idx = i;
                break;
            }
        }

        assert(idx != 999, "Too many views");

        self.views[idx] = ChatroomView{
            .new_messages = 0,
            .chatroom = self,
        };

        return &self.views[idx].?;
    }
};

fn connection_loop(data: ThreadData) void {
    var state = ServerState.listening;

    const timeval = mem.toBytes(posix.timeval{ .tv_sec = 1, .tv_usec = 0 });
    posix.setsockopt(data.conn.stream.handle, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &timeval) catch unreachable;

    var read_buf: [2048]u8 = undefined;
    const reader = data.conn.stream.reader();

    blk: while (true) {
        const result = reader.readUntilDelimiter(&read_buf, '\n');

        if (result) |msg| {
            log.info("[handler {}] received: '{s}'", .{ data.conn.address, msg });

            switch (state) {
                .listening => {
                    if (mem.eql(u8, msg, "q")) {
                        break :blk;
                    }
                    if (mem.eql(u8, msg, "m")) {
                        state = .expecting_msg;
                        continue;
                    }
                },
                .expecting_msg => {
                    data.chatroom.chatroom.new_msg(msg);

                    state = .listening;
                },
            }
        } else |err| switch (err) {
            error.WouldBlock => {},
            else => {
                log.err("[handler {}] read err: {}", .{ data.conn.address, err });

                data.conn.stream.writeAll("err\n") catch {};
                data.conn.stream.close();

                return;
            },
        }

        log.info("[handler {}] checking for new messages", .{ data.conn.address });

        const new_messages = @atomicLoad(u32, &data.chatroom.new_messages, builtin.AtomicOrder.acquire);
        if (new_messages > 0) {
            var i: usize = new_messages - 1;
            while (true) {
                const new_message = data.chatroom.view_i_latest_msg(i, &read_buf);
                data.conn.stream.writer().print("m\n{s}\n", .{new_message}) catch |err| {
                    log.err("[handler {}] read err: {}", .{ data.conn.address, err });
                    data.conn.stream.close();
                    return;
                };

                if (i == 0) {
                    break;
                }

                i -= 1;
            }
        }
    }
}
