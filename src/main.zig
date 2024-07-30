const std = @import("std");
const math = @import("math.zig");
const color = @import("color.zig");
const game = @import("game/game.zig");
const w = @import("window.zig");
const rl = @import("raylib");
const assert = @import("assert.zig").assert;
const print = std.debug.print;

const Map = game.map.MapNormal;
pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    // const seed: u64 = @intCast(std.time.milliTimestamp());
    // const seed: u64 = 69420;

    var map = Map.init();
    const settings = game.map.MapGenSettings{
        .noise_min = -0.005,
        .noise_max = 0.005,
        .continent_threshold = 0.25,
        .continent_octaves = 5,
        .continent_resolution = 0.005,
        .water_low_color = .{ .hue = 241, .saturation = 0.93, .value = 0.31 },
        .water_high_color = .{ .hue = 212, .saturation = 0.85, .value = 0.75 },
        .ground_low_color = .{ .hue = 122, .saturation = 0.60, .value = 0.47 },
        .ground_high_color = .{ .hue = 138, .saturation = 0.48, .value = 0.72 },
    };
    for (0..20) |_| {
        const seed: u64 = @intCast(std.time.milliTimestamp());
        map.generate(seed, settings);
        try map.export_to_file();
    }
    
    // w.init(800, 600);
    //
    // while (!w.shouldClose()) {
    //     rl.beginDrawing();
    //     defer rl.endDrawing();
    //
    //     rl.clearBackground(rl.Color.white);
    //
    //     for (0..map.grid.len) |i| {
    //         const x: i32 = @intCast(i % Map.MapWidth);
    //         const y: i32 = @intCast(i / Map.MapWidth);
    //
    //         rl.drawPixel(x, y, map.grid[i].color.to_raylib());
    //     }
    // }
    //
    // defer w.deinit();
}

test { _ = math; }
test { _ = color; }
test { _ = game; }
