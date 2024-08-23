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
    unknown,
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

pub const Map = struct {
    const Self = @This();
    pub const GridWidth = 200;

    grid: [GridWidth * GridWidth]Tile,
    seed: u64,

    pub fn generate(seed: u64, settings: MapGenSettings) Self {
        var rng = std.Random.DefaultPrng.init(seed);
        const noise = PerlinNoise.init(rng.random());

        assert(settings.continent_noise_min < settings.continent_noise_max, "Noise min must be less than noise max");
        assert(settings.sea_level >= 0 and settings.sea_level < 1, "Threshold must be >= 0 and < 1");

        var grid_buf: [GridWidth * GridWidth]Tile = undefined;

        for (0..(GridWidth * GridWidth)) |i| {
            const x: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i % GridWidth));
            const y: f32 = settings.continent_resolution * @as(f32, @floatFromInt(i / GridWidth));

            var tile: Tile = undefined;
            generate_altitude_pass(x, y, &noise, &tile, settings);
            grid_buf[i] = tile;
        }

        return Self{
            .grid = grid_buf,
            .grid_width = GridWidth,
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
        const width: i32 = @intCast(GridWidth);
        var image = rl.genImageColor(width, width, rl.Color.black);
        defer image.unload();

        for (0..self.grid.len) |i| {
            const x: i32 = @intCast(i % GridWidth);
            const y: i32 = @intCast(i / GridWidth);
            var col = rl.Color{
                .a = 255,
                .r = self.grid[i].r,
                .g = self.grid[i].g,
                .b = self.grid[i].b,
            };

            if (self.grid[i].tile_type == .unknown) {
                col = rl.Color{
                    .a = 255,
                    .r = 255,
                    .g = 255,
                    .b = 255,
                };
            }

            image.drawPixel(x, y, col);
        }

        return image.toTexture();
    }

    const MetadataLength: u32 = 8;

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

    pub fn encode_rle_client(self: Self, buf: []u8, world_known: *std.bit_set.ArrayBitSet(u8, GridWidth * GridWidth)) usize {
        var grid_idx: usize = 0;
        var buf_idx: usize = 0;

        while (grid_idx < self.grid.len) {
            const tile = self.grid[grid_idx];
            const num = 1 + self.encode_rle_client_look_ahead(grid_idx, world_known);

            assert(buf_idx + 4 < buf.len, "Buffer not long enough");

            var tile_type = tile.tile_type;
            if (!world_known.isSet(grid_idx)) {
                tile_type = .unknown;
            }

            buf[buf_idx] = num;
            buf[buf_idx + 1] = @as(u8, @intFromEnum(tile_type));
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

        const max = std.math.maxInt(u8) - 1;

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

    fn encode_rle_client_look_ahead(self: Self, start: usize, world_known: *std.bit_set.ArrayBitSet(u8, GridWidth * GridWidth)) u8 {
        const r = self.grid[start].r;
        const g = self.grid[start].g;
        const b = self.grid[start].b;
        const known = world_known.isSet(start);

        const max = std.math.maxInt(u8) - 1;

        var count: u8 = 0;
        for ((start + 1)..self.grid.len) |i| {
            const tile = self.grid[i];
            const tile_known = world_known.isSet(i);

            if (tile_known) {
                if (!known) {
                    return count;
                }
                if (tile.r != r or tile.g != g or tile.b != b) {
                    return count;
                }
            } else {
                if (known) {
                    return count;
                }
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

        const seed1: u8 = @intCast((self.seed >> 0) & 0xFF);
        const seed2: u8 = @intCast((self.seed >> 8) & 0xFF);
        const seed3: u8 = @intCast((self.seed >> 16) & 0xFF);
        const seed4: u8 = @intCast((self.seed >> 24) & 0xFF);
        const seed5: u8 = @intCast((self.seed >> 32) & 0xFF);
        const seed6: u8 = @intCast((self.seed >> 40) & 0xFF);
        const seed7: u8 = @intCast((self.seed >> 48) & 0xFF);
        const seed8: u8 = @intCast((self.seed >> 56) & 0xFF);

        buf[0] = seed1;
        buf[1] = seed2;
        buf[2] = seed3;
        buf[3] = seed4;
        buf[4] = seed5;
        buf[5] = seed6;
        buf[6] = seed7;
        buf[7] = seed8;
    }

    pub fn decode_rle(stream: []u8, client: bool) Self {
        std.debug.print("stream length: {} | {}\n", .{stream.len, stream.len / 5});

        var grid_buf: [GridWidth * GridWidth]Tile = undefined;

        const seed = if (client) 0 else decode_metadata(stream);

        var stream_idx: usize = if (client) 0 else MetadataLength;
        var grid_idx: usize = 0;

        while (stream_idx < stream.len) {
            assert(stream_idx + 4 < stream.len, "Stream not valid format");

            const num = stream[stream_idx];
            const tile_type: TileType = @enumFromInt(stream[stream_idx + 1]);
            const r = stream[stream_idx + 2];
            const g = stream[stream_idx + 3];
            const b = stream[stream_idx + 4];

            assert(grid_idx + num - 1 < grid_buf.len, "Stream not valid format, more tiles than size allows");

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

        assert(grid_idx == GridWidth * GridWidth, "Something went wrong");

        return Self{
            .grid = grid_buf,
            .grid_width = GridWidth,
            .seed = seed,
        };
    }

    fn decode_metadata(stream: []u8) u64 {
        assert(stream.len > MetadataLength, "Stream not valid length");

        const seed1 = @as(u64, @intCast(stream[0])) << 0;
        const seed2 = @as(u64, @intCast(stream[1])) << 8;
        const seed3 = @as(u64, @intCast(stream[2])) << 16;
        const seed4 = @as(u64, @intCast(stream[3])) << 24;
        const seed5 = @as(u64, @intCast(stream[4])) << 32;
        const seed6 = @as(u64, @intCast(stream[5])) << 40;
        const seed7 = @as(u64, @intCast(stream[6])) << 48;
        const seed8 = @as(u64, @intCast(stream[7])) << 56;

        const seed: u64 = seed1 | seed2 | seed3 | seed4 | seed5 | seed6 | seed7 | seed8;

        return seed;
    }
};
