const std = @import("std");
const math = @import("math.zig");
const w = @import("window.zig");
const rl = @import("raylib");
const assert = @import("debug.zig").assert;
const print = std.debug.print;

pub fn main() !void {
    const seed: u64 = @intCast(std.time.milliTimestamp());
    const noise = math.PerlinNoise.init(seed);

    const size = 200;
    const fidelity: f32 = 0.005;

    var smallest: f32 = 100;
    var largest: f32 = -100;

    const threshold = 0.4999;
    var tiles: [size * size]bool = undefined;
    // var colors: [size * size]u8 = undefined;
    for (0..size) |i| {
        for (0..size) |j| {
            const x: f32 = @as(f32, @floatFromInt(i)) * fidelity;
            const y: f32 = @as(f32, @floatFromInt(j)) * fidelity;
            const noise_val = noise.fbm(x, y, 5) * 0.5 + 0.5;
            tiles[(i * size) + j] = noise_val > threshold;

            if (noise_val > largest) {
                largest = noise_val;
            }
            if (noise_val < smallest) {
                smallest = noise_val;
            }
        }
    }

    print("smallest: {d}\n", .{smallest});
    print("largest: {d}\n", .{largest});

    w.init(800, 600);

    while (!w.shouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        const width = 1;
        for (0..size) |i| {
            for (0..size) |j| {
                // const col = colors[(i * size) + j];
                // rl.drawRectangle(@intCast(i * width), @intCast(j * width), width, width, rl.Color.init(col, col, col, 255));
                const green = tiles[(i * size) + j];
                if (green) {
                    rl.drawRectangle(@intCast(i * width), @intCast(j * width), width, width, rl.Color.green);
                } else {
                    rl.drawRectangle(@intCast(i * width), @intCast(j * width), width, width, rl.Color.blue);
                }
            }
        }
    }

    defer w.deinit();
}

test {
    _ = math;
}
