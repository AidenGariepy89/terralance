const std = @import("std");
const math = @import("math.zig");
const w = @import("window.zig");
const rl = @import("raylib");
const assert = @import("assert.zig").assert;
const print = std.debug.print;

pub fn main() !void {
    w.init(800, 600);

    while (!w.shouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
    }

    defer w.deinit();
}

test {
    _ = math;
}
