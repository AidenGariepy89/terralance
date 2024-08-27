const std = @import("std");
const net = std.net;
const server = @import("server.zig");

pub fn run() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, server.Port);

    var stream = try net.tcpConnectToAddress(addr);
    defer stream.close();

    try stream.writeAll("Hello world");
}
