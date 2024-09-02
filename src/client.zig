const std = @import("std");
const log = std.log;
const math = @import("math.zig");
const mem = std.mem;
const net = std.net;
const server = @import("server.zig");

pub fn run() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, server.Port);

    var stream = try net.tcpConnectToAddress(addr);
    defer stream.close();

    log.info("[client] connected to {}", .{addr});

    try handshake(stream, 2, 1);

    const res = try read_server_response(stream);
    switch (res) {
        .ready => {},
        .err => {
            var err_buf: [1024]u8 = undefined;
            const n = stream.readAll(&err_buf) catch unreachable;

            log.err("[client] recieved error from server: {s}", .{err_buf[0..n]});

            return error.ServerError;
        },
    }

    std.time.sleep(3_000_000_000);

    try stream.writeAll("m\nq\n");
}

fn handshake(stream: net.Stream, player_id: u64, game_id: u64) !void {
    log.debug("[client] performing handshake", .{});

    var packet: [16]u8 = undefined;
    const player_id_arr = math.u64_to_u8s(player_id);
    const game_id_arr = math.u64_to_u8s(game_id);
    mem.copyForwards(u8, &packet, &player_id_arr);
    mem.copyForwards(u8, packet[8..], &game_id_arr);

    try stream.writeAll(&packet);
}

const ServerResponse = enum {
    ready,
    err,
};

fn read_server_response(stream: net.Stream) !ServerResponse {
    const reader = stream.reader();

    var buf: [1024]u8 = undefined;
    const res = try reader.readUntilDelimiter(&buf, '\n');

    if (mem.eql(u8, res, "ready")) {
        return .ready;
    }
    if (mem.eql(u8, res, "err")) {
        return .err;
    }

    return error.UnexpectedResponse;
}
