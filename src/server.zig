const std = @import("std");
const database = @import("database.zig");
const log = std.log;
const math = @import("math.zig");
const mem = std.mem;
const net = std.net;
const t = std.testing;
const assert = @import("assert.zig").assert;
const Connection = net.Server.Connection;
const Thread = std.Thread;

pub const Port = 6969;
pub const db_controller = @import("server/db_controller.zig");

const ThreadData = struct {
    conn: Connection,
    db: database.DbRef,
};

pub fn run() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, Port);
    var s = try addr.listen(.{});
    defer s.deinit();

    var db = try database.init_db();

    log.info("[server] listening on {}", .{addr});
    defer log.info("[server] shutting down", .{});

    while (true) {
        const conn = try s.accept();
        _ = try Thread.spawn(.{}, handle, .{ ThreadData{
            .conn = conn,
            .db = database.DbRef{ .db = &db, .mutex = Thread.Mutex{} },
        } });
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
        log.err("[handler {}] handshake error: {}", .{conn.address, err});

        writer.print("err\n{}", .{err}) catch {};
        conn.stream.close();

        return;
    };

    log.debug("[handler {}] checking if game exists", .{conn.address});

    const game_exists = db_controller.game_exists(&db, handshake.game_id) catch |err| {
        log.err("[handler {}] db error: {}", .{conn.address, err});

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
        log.err("[handler {}] db error: {}", .{conn.address, err});

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
        log.err("[handler {}] write error: {}", .{data.conn.address, err});
        conn.stream.close();
        return;
    };
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
