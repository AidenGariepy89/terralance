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
                gs = game.GameState.new_game(null);
                c.cgs = gs.?.get_client_state();
            },
        }
    }
}

test { _ = math; }
test { _ = color; }
test { _ = game; }
test { _ = client; }
