//! Create data to represent a planet map. Store data maps to disk.
//! Load data maps from disk. Generate new planet maps from seed.

const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const color = @import("../color.zig");
const math = @import("../math.zig");
const assert = @import("../assert.zig").assert;
const PerlinNoise = math.PerlinNoise;

pub const TileType = enum {
    water,
    ground,
};

pub const Tile = struct {
    tile_type: TileType,
    color: color.RGB,
};

pub const MapGenSettings = struct {
    noise_min: f32,
    noise_max: f32,

    continent_resolution: f32,
    continent_threshold: f32,
    continent_octaves: u32,

    ground_high_color: color.HSV,
    ground_low_color: color.HSV,
    water_high_color: color.HSV,
    water_low_color: color.HSV,
};

pub const MapNormal = Map(200);

pub fn Map(comptime map_width: u32) type {
    return struct {
        const Self = @This();
        pub const MapWidth = map_width;

        grid: [MapWidth * MapWidth]Tile,
        seed: ?u64,

        pub fn init() Self {
            return Self{
                .grid = undefined,
                .seed = null,
            };
        }

        pub fn generate(self: *Self, seed: u64, settings: MapGenSettings) void {
            self.seed = seed;
            var rng = std.Random.DefaultPrng.init(seed);
            const noise = PerlinNoise.init(rng.random());

            assert(settings.noise_min < settings.noise_max, "Noise min must be less than noise max");
            assert(settings.continent_threshold > 0 and settings.continent_threshold < 1, "Threshold must be > 0 and < 1");

            for (0..MapWidth) |i| {
                for (0..MapWidth) |j| {
                    const x: f32 = @as(f32, @floatFromInt(j)) * settings.continent_resolution;
                    const y: f32 = @as(f32, @floatFromInt(i)) * settings.continent_resolution;

                    const noise_val = noise.fbm(x, y, settings.continent_octaves);
                    const val = math.progress(settings.noise_min, settings.noise_max, noise_val);

                    const tile = generate_tile_from_noise(val, settings);

                    const idx = (i * MapWidth) + j;
                    assert(idx < MapWidth * MapWidth, "Index out of bounds!");
                    self.grid[idx] = tile;
                }
            }
        }

        pub fn generate_with_info(self: *Self, seed: u64, settings: MapGenSettings, allocator: std.mem.Allocator) math.NoiseCollector.Report {
            self.seed = seed;
            var rng = std.Random.DefaultPrng.init(seed);
            var noise = math.NoiseCollector.init(allocator, rng.random());
            defer noise.deinit();

            assert(settings.noise_min < settings.noise_max, "Noise min must be less than noise max");
            assert(settings.continent_threshold > 0 and settings.continent_threshold < 1, "Threshold must be > 0 and < 1");

            for (0..MapWidth) |i| {
                for (0..MapWidth) |j| {
                    const x: f32 = @as(f32, @floatFromInt(j)) * settings.continent_resolution;
                    const y: f32 = @as(f32, @floatFromInt(i)) * settings.continent_resolution;

                    const noise_val = noise.fbm(x, y, settings.continent_octaves);
                    const val = math.progress(settings.noise_min, settings.noise_max, noise_val);

                    const tile = generate_tile_from_noise(val, settings);

                    const idx = (i * MapWidth) + j;
                    assert(idx < MapWidth * MapWidth, "Index out of bounds!");
                    self.grid[idx] = tile;
                }
            }

            return noise.report();
        }

        pub fn generate_tile_from_noise(val: f32, settings: MapGenSettings) Tile {
            var tile_type: TileType = undefined;
            var tile_color: color.HSV = undefined;
            if (val > settings.continent_threshold) {
                tile_type = .ground;

                const percent = math.progress(settings.continent_threshold, 1, val);
                tile_color = color.HSV{
                    .hue        = math.lerp(settings.ground_low_color.hue,        settings.ground_high_color.hue,        percent),
                    .saturation = math.lerp(settings.ground_low_color.saturation, settings.ground_high_color.saturation, percent),
                    .value      = math.lerp(settings.ground_low_color.value,      settings.ground_high_color.value,      percent),
                };
            } else {
                tile_type = .water;

                const percent = math.progress(0, settings.continent_threshold, val);
                tile_color = color.HSV{
                    .hue        = math.lerp(settings.water_low_color.hue,        settings.water_high_color.hue,        percent),
                    .saturation = math.lerp(settings.water_low_color.saturation, settings.water_high_color.saturation, percent),
                    .value      = math.lerp(settings.water_low_color.value,      settings.water_high_color.value,      percent),
                };
            }

            return .{ .tile_type = tile_type, .color = color.hsv_to_rgb(tile_color) };
        }

        pub fn generate_blank_map(self: *Self) void {
            const green_color = color.RGB{ .r = 56, .g = 143, .b = 79 };
            for (0..self.grid.len) |i| {
                self.grid[i] = Tile{
                    .tile_type = .ground,
                    .color = green_color,
                };
            }
        }

        pub fn export_to_file(self: Self) !void {
            var img = rl.genImageColor(Self.MapWidth, Self.MapWidth, rl.Color.black);
            for (0..self.grid.len) |i| {
                const x: i32 = @intCast(i % Self.MapWidth);
                const y: i32 = @intCast(i / Self.MapWidth);

                img.drawPixel(x, y, self.grid[i].color.to_raylib());
            }

            var buf: [64]u8 = undefined;
            const res = img.exportToFile(try std.fmt.bufPrintZ(&buf, "exports/map-{}.png", .{self.seed.?}));
            if (!res) {
                return error.FileSaveFailed;
            }
        }
    };
}

test "generating maps" {
    var map = MapNormal{ .grid = undefined };
    map.generate_blank_map();
}
