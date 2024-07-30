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
    const seed: u64 = @intCast(std.time.milliTimestamp());
    // const seed: u64 = 69420;

    var map = Map.init();
    const settings = game.map.MapGenSettings{
        .sea_level = 0.18,
        .continent_noise_min = -0.0043,
        .continent_noise_max = 0.005,
        .continent_octaves = 5,
        .continent_resolution = 0.012,
    };
    map.generate(seed, settings);

    // try csv(&map, .water);

    w.init(800, 600);
    defer w.deinit();

    var texture = visualize(&map);
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
            texture.unload();
            texture = visualize(&map);
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        texture.drawEx(center, 0, scale, rl.Color.white);
    }
}

fn csv(map: *Map, filter: game.map.TileType) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    var i: usize = 0;
    for (map.grid) |tile| {
        if (tile.tile_type != filter) {
            continue;
        }
        try stdout.print("{},", .{tile.altitude});
        i += 1;
    }
    try bw.flush();
}

fn visualize(map: *Map) rl.Texture2D {
    const water_shallow = color.HSV{ .hue = 227, .saturation = 0.75, .value = 0.97 };
    const water_deep = color.HSV{ .hue = 227, .saturation = 0.97, .value = 0.26 };
    const ground_low = color.HSV{ .hue = 130, .saturation = 0.88, .value = 0.31 };
    const ground_high = color.HSV{ .hue = 145, .saturation = 0.52, .value = 0.64 };

    var image = rl.genImageColor(Map.MapWidth, Map.MapWidth, rl.Color.black);

    for (0..map.grid.len) |i| {
        const x: i32 = @intCast(i % Map.MapWidth);
        const y: i32 = @intCast(i / Map.MapWidth);
        const altitude: f32 = @as(f32, @floatFromInt(map.grid[i].altitude)) / 255;
        var col: color.RGB = undefined;

        if (map.grid[i].tile_type == .ground) {
            col = color.hsv_to_rgb(.{
                .hue        = math.lerp(ground_low.hue,        ground_high.hue,        altitude),
                .saturation = math.lerp(ground_low.saturation, ground_high.saturation, altitude),
                .value      = math.lerp(ground_low.value,      ground_high.value,      altitude),
            });
        } else {
            col = color.hsv_to_rgb(.{
                .hue        = math.lerp(water_deep.hue,        water_shallow.hue,        altitude),
                .saturation = math.lerp(water_deep.saturation, water_shallow.saturation, altitude),
                .value      = math.lerp(water_deep.value,      water_shallow.value,      altitude),
            });
        }

        image.drawPixel(x, y, col.to_raylib());
    }

    const texture = rl.loadTextureFromImage(image);
    image.unload();

    return texture;
}

test { _ = math; }
test { _ = color; }
test { _ = game; }
