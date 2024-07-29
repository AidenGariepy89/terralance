const std = @import("std");
const t = std.testing;
const assert = @import("debug.zig").assert;

pub const pi = std.math.pi;

pub const Vec = struct {
    x: f32,
    y: f32,

    const zero: Vec = .{ .x = 0, .y = 0 };
    const one: Vec = .{ .x = 1, .y = 1 };
    const right: Vec = .{ .x = 1, .y = 0 };
    const left: Vec = .{ .x = -1, .y = 0 };
    const up: Vec = .{ .x = 0, .y = -1 };
    const down: Vec = .{ .x = 0, .y = 1 };

    pub fn init(x: f32, y: f32) Vec {
        return .{ .x = x, .y = y };
    }

    pub fn x_i32(self: Vec) i32 {
        return @intFromFloat(self.x);
    }

    pub fn y_i32(self: Vec) i32 {
        return @intFromFloat(self.y);
    }

    pub fn add(self: Vec, other: Vec) Vec {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn subtract(self: Vec, other: Vec) Vec {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn scale(self: Vec, scalar: f32) Vec {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    pub fn dot(self: Vec, other: Vec) f32 {
        return (self.x * other.x) + (self.y * other.y);
    }

    pub fn cross(self: Vec, other: Vec) f32 {
        return (self.x * other.y) - (self.y * other.x);
    }

    pub fn mag(self: Vec) f32 {
        return @sqrt((self.x * self.x) + (self.y * self.y));
    }

    pub fn norm(self: Vec) Vec {
        const scalar = 1.0 / self.mag();
        return self.scale(scalar);
    }
};

// Perlin Noise
pub const PerlinNoise = struct {
    const Self = @This();

    permutations: [512]u8,
    seed: u64,

    pub fn init(seed: u64) Self {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        var perms: [256]u8 = undefined;
        for (0..256) |i| {
            perms[i] = @intCast(i);
        }
        for (0..255) |i| {
            // shuffle
            const j = 255 - i;
            const temp = perms[j];
            const idx = random.uintLessThan(usize, j);
            perms[j] = perms[idx];
            perms[idx] = temp;
        }

        // double
        var p: [512]u8 = undefined;
        for (0..512) |i| {
            p[i] = perms[i % 256];
        }

        return .{
            .permutations = p,
            .seed = seed,
        };
    }

    /// Fractal Brownian Motion
    pub fn fbm(self: Self, x: f32, y: f32, octaves: u32) f32 {
        var result: f32 = 0;
        var frequency: f32 = 1;
        var amplitude: f32 = 0.005;

        for (0..octaves) |_| {
            result += amplitude * self.noise_2d(x * frequency, y * frequency);

            amplitude *= 0.5;
            frequency *= 2;
        }

        return result;
    }

    pub fn noise_2d(self: Self, x: f32, y: f32) f32 {
        const x_wrapped = @mod(x, 256);
        const y_wrapped = @mod(y, 256);

        const sector_x: u32 = @intFromFloat(x_wrapped);
        const sector_y: u32 = @intFromFloat(y_wrapped);

        const x_f = x_wrapped - @trunc(x_wrapped);
        const y_f = y_wrapped - @trunc(y_wrapped);

        const r_top_left     = Vec.init(x_f, y_f);
        const r_top_right    = Vec.init(x_f - 1, y_f);
        const r_bottom_left  = Vec.init(x_f, y_f - 1);
        const r_bottom_right = Vec.init(x_f - 1, y_f - 1);

        const p = &self.permutations;
        const hash_top_left     = p[p[sector_x]                + sector_y];
        const hash_top_right    = p[p[inc_with_wrap(sector_x)] + sector_y];
        const hash_bottom_left  = p[p[sector_x]                + inc_with_wrap(sector_y)];
        const hash_bottom_right = p[p[inc_with_wrap(sector_x)] + inc_with_wrap(sector_y)];
        const c_top_left     = perm_hash(hash_top_left);
        const c_top_right    = perm_hash(hash_top_right);
        const c_bottom_left  = perm_hash(hash_bottom_left);
        const c_bottom_right = perm_hash(hash_bottom_right);

        const dot_top_left     = r_top_left.dot(c_top_left);
        const dot_top_right    = r_top_right.dot(c_top_right);
        const dot_bottom_left  = r_bottom_left.dot(c_bottom_left);
        const dot_bottom_right = r_bottom_right.dot(c_bottom_right);

        const u = ease(x_f);
        const v = ease(y_f);

        return lerp(
            lerp(dot_top_left, dot_bottom_left, v),
            lerp(dot_top_right, dot_bottom_right, v),
            u,
        );
    }

    fn inc_with_wrap(x: u32) u32 {
        return (x + 1) % 256;
    }

    fn perm_hash(hash: u8) Vec {
        return switch (hash % 4) {
            0 => Vec.init(1, 1),
            1 => Vec.init(1, -1),
            2 => Vec.init(-1, 1),
            3 => Vec.init(-1, -1),
            else => unreachable,
        };
    }

    fn ease(x: f32) f32 {
        return x * x * x * (x * (6 * x - 15) + 10);
    }
};

pub fn lerp(a1: f32, a2: f32, percent: f32) f32 {
    return a1 + percent * (a2 - a1);
}

test "dot and cross" {
    const vec_a = Vec.init(1, 2);
    const vec_b = Vec.init(2, 1);

    const cross = vec_a.cross(vec_b);
    try t.expectEqual(-3, cross);

    const dot = vec_a.dot(vec_b);
    try t.expectEqual(4, dot);
}
