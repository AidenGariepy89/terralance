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

pub const RawTile = struct {
    tile_type: TileType,
    /// 0-255, sea level to mountain peak for ground,
    /// ocean floor to sea level for water.
    altitude: u8,

    temperature: u8,
};

pub const Tile = struct {
    tile_type: TileType,
    r: u8,
    g: u8,
    b: u8,
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

pub const Map = struct {
    const Self = @This();

    grid_width: u32,
    grid: []Tile,
    seed: u64,

    pub fn generate(grid_width: u32, grid_buf: []Tile, seed: u64, settings: MapGenSettings) Self {
        var rng = std.Random.DefaultPrng.init(seed);
        const noise = PerlinNoise.init(rng.random());

        assert(grid_width * grid_width <= grid_buf.len, "Buffer not long enough");
        assert(settings.continent_noise_min < settings.continent_noise_max, "Noise min must be less than noise max");
        assert(settings.sea_level >= 0 and settings.sea_level < 1, "Threshold must be >= 0 and < 1");

        for (0..(grid_width * grid_width)) |i| {
            const x: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i % grid_width));
            const y: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i / grid_width));

            var tile: Tile = undefined;
            generate_altitude_pass(x, y, &noise, &tile, settings);
            grid_buf[i] = tile;
        }

        return Self{
            .grid = grid_buf[0..(grid_width * grid_width)],
            .grid_width = grid_width,
            .seed = seed,
        };
    }

    pub fn generate_altitude_pass(x: f32, y: f32, noise: *const PerlinNoise, out_tile: *Tile, settings: MapGenSettings) void {
        const noise_val = noise.fbm(x, y, settings.continent_octaves);
        const val = math.progress(settings.continent_noise_min, settings.continent_noise_max, noise_val);

        if (val >= settings.sea_level) {
            const altitude = math.progress(settings.sea_level, 1, val);
            const tile_type = TileType.ground;
            const col = get_tile_color(altitude, tile_type, settings);

            out_tile.tile_type = tile_type;
            out_tile.r = col.r;
            out_tile.g = col.g;
            out_tile.b = col.b;
        } else {
            const altitude = math.progress(0, settings.sea_level, val);
            const tile_type = TileType.water;
            const col = get_tile_color(altitude, tile_type, settings);

            out_tile.tile_type = tile_type;
            out_tile.r = col.r;
            out_tile.g = col.g;
            out_tile.b = col.b;
        }
    }

    pub fn get_tile_color(altitude: f32, tile_type: TileType, settings: MapGenSettings) color.RGB {
        _ = settings;

        const water_shallow = color.HSV{ .hue = 227, .saturation = 0.75, .value = 0.97 };
        const water_deep = color.HSV{ .hue = 227, .saturation = 0.97, .value = 0.26 };
        const ground_low = color.HSV{ .hue = 130, .saturation = 0.88, .value = 0.31 };
        const ground_high = color.HSV{ .hue = 145, .saturation = 0.52, .value = 0.64 };

        if (tile_type == .ground) {
            return color.hsv_to_rgb(ground_low.lerp(ground_high, altitude));
        } else {
            return color.hsv_to_rgb(water_deep.lerp(water_shallow, altitude));
        }
    }

    pub fn visualize(self: Self) rl.Texture2D {
        const width: i32 = @intCast(self.grid_width);
        var image = rl.genImageColor(width, width, rl.Color.black);
        defer image.unload();

        for (0..self.grid.len) |i| {
            const x: i32 = @intCast(i % self.grid_width);
            const y: i32 = @intCast(i / self.grid_width);
            const col = rl.Color{
                .a = 255,
                .r = self.grid[i].r,
                .g = self.grid[i].g,
                .b = self.grid[i].b,
            };

            image.drawPixel(x, y, col);
        }

        return image.toTexture();
    }

    const MetadataLength: u32 = 10;

    pub fn encode_rle(self: Self, buf: []u8) usize {
        self.encode_metadata(buf);

        var grid_idx: usize = 0;
        var buf_idx: usize = MetadataLength;

        while (grid_idx < self.grid.len) {
            const tile = self.grid[grid_idx];
            const num = 1 + self.encode_rle_look_ahead(grid_idx);

            assert(buf_idx + 4 < buf.len, "Buffer not long enough");

            buf[buf_idx] = num;
            buf[buf_idx + 1] = @as(u8, @intFromEnum(tile.tile_type));
            buf[buf_idx + 2] = tile.r;
            buf[buf_idx + 3] = tile.g;
            buf[buf_idx + 4] = tile.b;

            grid_idx += num;
            buf_idx += 5;
        }

        return buf_idx;
    }

    fn encode_rle_look_ahead(self: Self, start: usize) u8 {
        const r = self.grid[start].r;
        const g = self.grid[start].g;
        const b = self.grid[start].b;

        const max = std.math.maxInt(u8);

        var count: u8 = 0;
        for ((start + 1)..self.grid.len) |i| {
            const tile = self.grid[i];

            if (tile.r != r or tile.g != g or tile.b != b) {
                return count;
            }

            count += 1;

            if (count >= max) {
                return max;
            }
        }

        return count;
    }

    fn encode_metadata(self: Self, buf: []u8) void {
        assert(buf.len > MetadataLength, "Buffer not long enough");

        const multiple: u8 = @intCast(self.grid_width / 256);
        const remainder: u8 = @intCast(self.grid_width % 256);

        const seed1: u8 = @intCast((self.seed >> 0) & 0xFF);
        const seed2: u8 = @intCast((self.seed >> 8) & 0xFF);
        const seed3: u8 = @intCast((self.seed >> 16) & 0xFF);
        const seed4: u8 = @intCast((self.seed >> 24) & 0xFF);
        const seed5: u8 = @intCast((self.seed >> 32) & 0xFF);
        const seed6: u8 = @intCast((self.seed >> 40) & 0xFF);
        const seed7: u8 = @intCast((self.seed >> 48) & 0xFF);
        const seed8: u8 = @intCast((self.seed >> 56) & 0xFF);

        buf[0] = multiple;
        buf[1] = remainder;
        buf[2] = seed1;
        buf[3] = seed2;
        buf[4] = seed3;
        buf[5] = seed4;
        buf[6] = seed5;
        buf[7] = seed6;
        buf[8] = seed7;
        buf[9] = seed8;
    }

    pub fn decode_rle(stream: []u8, grid_buf: []Tile) Self {
        const metadata = decode_metadata(stream);
        const grid_width = metadata.grid_width;
        assert(grid_width * grid_width <= grid_buf.len, "Grid buffer not long enough");

        var stream_idx: usize = MetadataLength;
        var grid_idx: usize = 0;

        while (stream_idx < stream.len) {
            assert(stream_idx + 4 < stream.len, "Stream not valid format");

            const num = stream[stream_idx];
            const tile_type: TileType = @enumFromInt(stream[stream_idx + 1]);
            const r = stream[stream_idx + 2];
            const g = stream[stream_idx + 3];
            const b = stream[stream_idx + 4];

            assert(grid_idx + num - 1 < grid_buf.len, "Grid buffer not long enough");

            for (0..num) |i| {
                grid_buf[grid_idx + i] = Tile{
                    .tile_type = tile_type,
                    .r = r,
                    .g = g,
                    .b = b,
                };
            }

            stream_idx += 5;
            grid_idx += num;
        }

        assert(grid_idx == grid_width * grid_width, "Something went wrong");

        return Self{
            .grid = grid_buf[0..(grid_width * grid_width)],
            .grid_width = grid_width,
            .seed = metadata.seed,
        };
    }

    const Metadata = struct {
        grid_width: u32,
        seed: u64,
    };

    fn decode_metadata(stream: []u8) Metadata {
        assert(stream.len > 2, "Stream not valid length");

        const multiple: u32 = @intCast(stream[0]);
        const remainder: u32 = @intCast(stream[1]);

        const grid_width = (multiple * 256) + remainder;

        const seed1 = @as(u64, @intCast(stream[2])) << 0;
        const seed2 = @as(u64, @intCast(stream[3])) << 8;
        const seed3 = @as(u64, @intCast(stream[4])) << 16;
        const seed4 = @as(u64, @intCast(stream[5])) << 24;
        const seed5 = @as(u64, @intCast(stream[6])) << 32;
        const seed6 = @as(u64, @intCast(stream[7])) << 40;
        const seed7 = @as(u64, @intCast(stream[8])) << 48;
        const seed8 = @as(u64, @intCast(stream[9])) << 56;

        const seed: u64 = seed1 | seed2 | seed3 | seed4 | seed5 | seed6 | seed7 | seed8;

        return .{
            .grid_width = grid_width,
            .seed = seed,
        };
    }
};

pub fn MapOld(comptime map_width: u32) type {
    return struct {
        const Self = @This();
        pub const MapWidth = map_width;

        grid: [MapWidth * MapWidth]RawTile,
        seed: u64,

        pub fn width(self: *const Self) u32 {
            _ = self;
            return Self.MapWidth;
        }

        pub fn generate(seed: u64, settings: MapGenSettings) Self {
            var rng = std.Random.DefaultPrng.init(seed);
            const noise = PerlinNoise.init(rng.random());

            assert(settings.continent_noise_min < settings.continent_noise_max, "Noise min must be less than noise max");
            assert(settings.sea_level >= 0 and settings.sea_level < 1, "Threshold must be >= 0 and < 1");

            var grid: [MapWidth * MapWidth]RawTile = undefined;

            for (0..(MapWidth * MapWidth)) |i| {
                var tile: RawTile = undefined;
                generate_altitude_pass(i, &noise, settings, &tile);
                generate_temperature_pass(i, &noise, settings, &tile);
                grid[i] = tile;
            }

            return Self{
                .grid = grid,
                .seed = seed,
            };
        }

        pub fn generate_altitude_pass(i: usize, noise: *const PerlinNoise, settings: MapGenSettings, out_tile: *RawTile) void {
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

        pub fn generate_temperature_pass(i: usize, noise: *const PerlinNoise, settings: MapGenSettings, out_tile: *RawTile) void {
            const x: f32 = settings.temperature_resolution * @as(f32, @floatFromInt(i % Self.MapWidth));
            const y: f32 = settings.temperature_resolution * @as(f32, @floatFromInt(i / Self.MapWidth));

            const noise_val = noise.fbm(x, y, settings.temperature_octaves);
            const val = math.progress(settings.temperature_noise_min, settings.temperature_noise_max, noise_val);

            out_tile.temperature = @intFromFloat(@round(val * 255));
        }

        pub fn visualize(self: *const Self) rl.Texture2D {
            const water_shallow = color.HSV{ .hue = 227, .saturation = 0.75, .value = 0.97 };
            const water_deep = color.HSV{ .hue = 227, .saturation = 0.97, .value = 0.26 };
            const ground_low = color.HSV{ .hue = 130, .saturation = 0.88, .value = 0.31 };
            const ground_high = color.HSV{ .hue = 145, .saturation = 0.52, .value = 0.64 };

            var image = rl.genImageColor(Self.MapWidth, Self.MapWidth, rl.Color.black);

            for (0..self.grid.len) |i| {
                const x: i32 = @intCast(i % Self.MapWidth);
                const y: i32 = @intCast(i / Self.MapWidth);
                const altitude: f32 = @as(f32, @floatFromInt(self.grid[i].altitude)) / 255;
                var col: color.RGB = undefined;

                if (self.grid[i].tile_type == .ground) {
                    col = color.hsv_to_rgb(ground_low.lerp(ground_high, altitude));
                } else {
                    col = color.hsv_to_rgb(water_deep.lerp(water_shallow, altitude));
                }

                image.drawPixel(x, y, col.to_raylib());
            }

            const texture = rl.loadTextureFromImage(image);
            image.unload();

            return texture;
        }

        pub fn visualize_temperature(self: *const Self) rl.Texture2D {
            const cold = color.HSV{ .hue = 267, .saturation = 1.00, .value = 1.00 };
            const hot = color.HSV{ .hue = 0, .saturation = 1.00, .value = 1.00 };

            var image = rl.genImageColor(Self.MapWidth, Self.MapWidth, rl.Color.black);
            for (0..self.grid.len) |i| {
                const x: i32 = @intCast(i % Self.MapWidth);
                const y: i32 = @intCast(i / Self.MapWidth);
                const temperature: f32 = @as(f32, @floatFromInt(self.grid[i].temperature)) / 255;

                const col = color.hsv_to_rgb(.{
                    .hue = math.lerp(cold.hue, hot.hue, temperature),
                    .saturation = 1,
                    .value = 1,
                });

                image.drawPixel(x, y, col.to_raylib());
            }

            const texture = rl.loadTextureFromImage(image);
            image.unload();

            return texture;
        }
    };
}
