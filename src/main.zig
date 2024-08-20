const std = @import("std");
const math = @import("math.zig");
const color = @import("color.zig");
const game = @import("game/game.zig");
const client = @import("client/client.zig");
const w = @import("window.zig");
const rl = @import("raylib");
const assert = @import("assert.zig").assert;
const print = std.debug.print;

pub fn main() !void {
    // var gs = game.GameState.new_game(.{
    //     .seed = 69420,
    // });
    //
    // var buf: [200 * 200 * 5]u8 = undefined;
    // const n = gs.world_map.encode_rle(&buf);
    //
    // const stdout = std.io.getStdOut();
    // try stdout.writeAll(buf[0..n]);

    if (std.os.argv.len > 1) {
        try run_server();
    } else {
        try run_client();
    }
}

fn run_server() !void {
    var buf: [4096]u8 = undefined;
    var str: []u8 = undefined;
    var written: usize = 0;

    const args = std.os.argv[1..];
    for (args) |arg| {
        // try stdout.print("{s}\n", .{arg});
        const result = try std.fmt.bufPrint(buf[written..buf.len], "{s} ", .{arg});
        written += result.len;
        str = buf[0..written];
    }

    const stdout_file = std.io.getStdOut();
    defer stdout_file.close();
    const stdin_file = std.io.getStdIn();
    defer stdin_file.close();

    const stdout = stdout_file.writer();
    const stdin = stdin_file.reader();

    var scratch_buf: [4096]u8 = undefined;
    var scratch_written: usize = 0;
    while (true) {
        const c = try stdin.readByte();
        if (c == '\n') {
            if (std.mem.eql(u8, scratch_buf[0..scratch_written], "Q")) {
                break;
            } else if (std.mem.eql(u8, scratch_buf[0..scratch_written], "W")) {
                const n = try stdout.write(str);
                assert(n == str.len, "Expected to write full str len");
                scratch_written = 0;
            } else {
                const n = try stdout.write(scratch_buf[0..scratch_written]);
                assert(n == scratch_written, "I think this is true");
                scratch_written = 0;
            }
        }

        assert(scratch_written < scratch_buf.len, "Exceeded scratch buffer size");

        scratch_buf[scratch_written] = c;
        scratch_written += 1;
    }
}

fn run_client() !void {
    var gs: ?game.GameState = null;

    var c = client.Client.init();
    defer c.deinit();

    while (true) {
        if (rl.isKeyPressed(.key_r)) {
            c.restart();
            gs = null;
        }

        const req = c.update() orelse continue;

        switch (req) {
            .quit => |err| {
                try err;
                break;
            },
            .new_game => {
                gs = game.GameState.new_game(.{});
                c.cgs = gs.?.get_client_state();
            },
        }
    }
}

test {
    _ = math;
}
test {
    _ = color;
}
test {
    _ = game;
}
test {
    _ = client;
}
