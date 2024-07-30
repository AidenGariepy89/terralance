const std = @import("std");
const t = std.testing;
const assert = @import("assert.zig").assert;

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
        const m = self.mag();
        assert(m != 0, "Can't normalize a vector with no length!");

        const scalar = 1.0 / m;
        return self.scale(scalar);
    }
};

// Perlin Noise
pub const PerlinNoise = struct {
    const Self = @This();

    permutations: [512]u8,

    pub fn init(random: std.Random) Self {
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

        return .{ .permutations = p };
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
    assert(percent >= 0 and percent <= 1, "Percent must be >= 0 and <= 1");
    return a1 + percent * (a2 - a1);
}

pub const HSV = struct {
    /// In degrees, 0 <= hue <= 360
    hue: f32,
    saturation: f32,
    value: f32,
};

pub const RGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub fn hsv_to_rgb(hsv: HSV) RGB {
    assert(hsv.hue >= 0 and hsv.hue <= 360 , "Hue is in degrees and must be >= 0 and <= 360");
    assert(hsv.saturation >= 0 and hsv.saturation <= 1, "Saturation must be >= 0 and <= 1");
    assert(hsv.value >= 0 and hsv.value <= 1, "Value must be >= 0 and <= 1");

    const r_f = hsv_to_rgb_transformation(hsv, 5);
    const g_f = hsv_to_rgb_transformation(hsv, 3);
    const b_f = hsv_to_rgb_transformation(hsv, 1);

    return RGB{
        .r = @intFromFloat(@round(r_f * 255)),
        .g = @intFromFloat(@round(g_f * 255)),
        .b = @intFromFloat(@round(b_f * 255)),
    };
}

fn hsv_to_rgb_transformation(hsv: HSV, n: f32) f32 {
    const k: f32 = @mod((n + hsv.hue / 60), 6);
    const result: f32 = hsv.value - hsv.value * hsv.saturation * @max(0, @min(k, @min(4 - k, 1)));
    assert(result >= 0 and result <= 1, "Result must be >= 0 and <= 1");
    return result;
}

test "dot and cross" {
    const vec_a = Vec.init(1, 2);
    const vec_b = Vec.init(2, 1);

    const cross = vec_a.cross(vec_b);
    try t.expectEqual(-3, cross);

    const dot = vec_a.dot(vec_b);
    try t.expectEqual(4, dot);
}

test "hsv to rgb" {
    const input_red = HSV{
        .hue = 0,
        .saturation = 1,
        .value = 1,
    };
    const expected_red = RGB{
        .r = 255,
        .g = 0,
        .b = 0,
    };

    const actual_red = hsv_to_rgb(input_red);
    try t.expectEqual(expected_red, actual_red);

    const input_purple = HSV{
        .hue = 283,
        .saturation = 0.49,
        .value = 0.92,
    };
    const expected_purple = RGB{
        .r = 202,
        .g = 120,
        .b = 235,
    };

    const actual_purple = hsv_to_rgb(input_purple);
    try t.expectEqual(expected_purple, actual_purple);
}
