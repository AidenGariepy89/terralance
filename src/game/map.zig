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
    /// 0-255, sea level to mountain peak for ground,
    /// ocean floor to sea level for water.
    altitude: u8,

    temperature: u8,
};

pub const MapGenSettings = struct {
    sea_level: f32,

    continent_noise_min: f32,
    continent_noise_max: f32,
    continent_resolution: f32,
    continent_octaves: u32,

    temperature_noise_min: f32,
    temperature_noise_max: f32,
    temperature_resolution: f32,
    temperature_octaves: u32,
};

pub const MapSmall = Map(100);
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

            assert(settings.continent_noise_min < settings.continent_noise_max, "Noise min must be less than noise max");
            assert(settings.sea_level >= 0 and settings.sea_level < 1, "Threshold must be >= 0 and < 1");

            for (0..(MapWidth*MapWidth)) |i| {
                var tile: Tile = undefined;
                generate_altitude_pass(i, &noise, settings, &tile);
                generate_temperature_pass(i, &noise, settings, &tile);
                self.grid[i] = tile;
            }
        }

        pub fn generate_altitude_pass(i: usize, noise: *const PerlinNoise, settings: MapGenSettings, out_tile: *Tile) void {
            const x: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i % Self.MapWidth));
            const y: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i / Self.MapWidth));

            const noise_val = noise.fbm(x, y, settings.continent_octaves);
            const val = math.progress(settings.continent_noise_min, settings.continent_noise_max, noise_val);

            if (val >= settings.sea_level) {
                out_tile.tile_type = .ground;
                out_tile.altitude = @intFromFloat(@round(math.progress(settings.sea_level, 1, val) * 255));
            } else {
                out_tile.tile_type = .water;
                out_tile.altitude = @intFromFloat(@round(math.progress(0, settings.sea_level, val) * 255));
            }
        }

        pub fn generate_temperature_pass(i: usize, noise: *const PerlinNoise, settings: MapGenSettings, out_tile: *Tile) void {
            const x: f32 = settings.temperature_resolution * @as(f32, @floatFromInt(i % Self.MapWidth));
            const y: f32 = settings.temperature_resolution * @as(f32, @floatFromInt(i / Self.MapWidth));

            const noise_val = noise.fbm(x, y, settings.temperature_octaves);
            const val = math.progress(settings.temperature_noise_min, settings.temperature_noise_max, noise_val);

            out_tile.temperature = @intFromFloat(@round(val * 255));
        }

        pub fn generate_blank_map(self: *Self) void {
            for (0..self.grid.len) |i| {
                self.grid[i] = Tile{
                    .tile_type = .ground,
                    .altitude = 0,
                };
            }
        }
    };
}

test "generating maps" {
    var map = MapNormal{ .grid = undefined };
    map.generate_blank_map();
}