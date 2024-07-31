const std = @import("std");
const math = @import("math.zig");
const color = @import("color.zig");
const game = @import("game/game.zig");
const w = @import("window.zig");
const rl = @import("raylib");
const assert = @import("assert.zig").assert;
const print = std.debug.print;

const Map = game.map.MapSmall;
pub fn main() !void {
    // const seed: u64 = @intCast(std.time.milliTimestamp());
    const seed: u64 = 69420;

    var map = Map.init();
    const settings = game.map.MapGenSettings{
        .sea_level = 0.18,

        .continent_noise_min = -0.0043,
        .continent_noise_max = 0.005,
        .continent_octaves = 5,
        .continent_resolution = 0.012,

        .temperature_noise_min = -0.005,
        // .temperature_noise_min = -0.0043,
        .temperature_noise_max = 0.0045,
        // .temperature_noise_max = 0.005,
        .temperature_octaves = 2,
        .temperature_resolution = 0.02,
    };
    map.generate(seed, settings);

    // try csv(&map, .water);

    w.init(800, 600);
    defer w.deinit();

    const VisualizeMode = enum {
        map,
        temp,
    };

    var mode: VisualizeMode = .temp;
    var map_texture = map.visualize();
    var temperature_texture = map.visualize_temperature();
    const scale: f32 = 3;
    const map_width: f32 = @floatFromInt(Map.MapWidth);

    while (!w.shouldClose()) {
        const center = rl.Vector2{
            .x = w.wh_f() - map_width * 0.5 * scale,
            .y = w.hh_f() - map_width * 0.5 * scale,
        };

        if (rl.isKeyPressed(.key_space)) {
            const new_seed: u64 = @intCast(std.time.milliTimestamp());
            map.generate(new_seed, settings);
            map_texture.unload();
            map_texture = map.visualize();
            temperature_texture.unload();
            temperature_texture = map.visualize_temperature();
        }

        if (rl.isKeyPressed(.key_m)) {
            mode = if (mode == .map) .temp else .map;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        switch (mode) {
            .map => map_texture.drawEx(center, 0, scale, rl.Color.white),
            .temp => temperature_texture.drawEx(center, 0, scale, rl.Color.white),
        }
    }
}

test { _ = math; }
test { _ = color; }
test { _ = game; }
