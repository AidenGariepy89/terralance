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

const ThreadData = struct {
    conn: Connection,
    db: database.DbRef,
};

pub fn run() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, Port);
    var s = try addr.listen(.{});
    defer s.deinit();

    var db = try database.init_db();

    while (true) {
        const conn = try s.accept();

        _ = try Thread.spawn(.{}, handle, .{ ThreadData{
            .conn = conn,
            .db = database.DbRef{ .db = &db, .mutex = Thread.Mutex{} },
        } });
    }
}

fn handle(data: ThreadData) void {
    var buf: [1024]u8 = undefined;
    const n = data.conn.stream.readAll(&buf) catch |err| {
        log.err("[thread] read err: {}", .{err});

        data.conn.stream.writeAll("err") catch {};
        data.conn.stream.close();

        return;
    };

    std.debug.print("{s}\n", .{buf[0..n]});
}
