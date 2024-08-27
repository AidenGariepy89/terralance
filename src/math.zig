const std = @import("std");
const testing = std.testing;
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

    pub fn lerp(self: Vec, other: Vec, t: f32) Vec {
        return self.add(other.subtract(self).scale(t));
    }
};

pub const NoiseCollector = struct {
    const Self = @This();
    const List = std.ArrayList(f32);

    pub const Report = struct {
        min: f32,
        max: f32,
        avg: f32,
        med: f32,

        pub fn print(self: Report) void {
            std.debug.print("Noise Collector Report:\n", .{});
            std.debug.print("  Min: {d}\n", .{self.min});
            std.debug.print("  Max: {d}\n", .{self.max});
            std.debug.print("  Avg: {d}\n", .{self.avg});
            std.debug.print("  Med: {d}\n", .{self.med});
        }
    };

    noise: PerlinNoise,
    values: List,

    pub fn init(allocator: std.mem.Allocator, random: std.Random) Self {
        return Self{
            .noise = PerlinNoise.init(random),
            .values = List.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
        self.* = undefined;
    }

    /// Fractal Brownian Motion
    pub fn fbm(self: *Self, x: f32, y: f32, octaves: u32) f32 {
        const result = self.noise.fbm(x, y, octaves);
        self.values.append(result) catch unreachable;
        return result;
    }

    pub fn report(self: Self) Report {
        var min: f32 = 100;
        var max: f32 = -100;
        var sum: f32 = 0;

        for (self.values.items) |item| {
            if (item < min) {
                min = item;
            }
            if (item > max) {
                max = item;
            }
            sum += item;
        }

        const avg = sum / @as(f32, @floatFromInt(self.values.items.len));
        const med = self.values.items[self.values.items.len / 2];

        return Report{
            .min = min,
            .max = max,
            .avg = avg,
            .med = med,
        };
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

        assert(result >= -1 and result <= 1, "Result must be >= -1 and <= 1");
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

        const result = lerp(
            lerp(dot_top_left, dot_bottom_left, v),
            lerp(dot_top_right, dot_bottom_right, v),
            u,
        );
        assert(result >= -1 and result <= 1, "Result must be >= -1 and <= 1");
        return result;
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

/// Returns a percentage of the progress of val from min to max.
/// If val is less than min, returns 0.
/// If val is greater than max, returns 1.
pub fn progress(min: f32, max: f32, val: f32) f32 {
    assert(min < max, "min must be less than max");

    if (val < min) {
        return 0;
    }
    if (val > max) {
        return 1;
    }

    const result = (val - min) / (max - min);
    assert(result >= 0 and result <= 1, "result must be >= 0 and <= 1");
    return result;
}

pub fn cubic_bezier(p0: Vec, p1: Vec, p2: Vec, p3: Vec, t: f32) Vec {
    const q0 = p0.lerp(p1, t);
    const q1 = p1.lerp(p2, t);
    const q2 = p2.lerp(p3, t);

    const r0 = q0.lerp(q1, t);
    const r1 = q1.lerp(q2, t);

    const s = r0.lerp(r1, t);
    return s;
}

pub fn u64_to_u8s(input: u64) [8]u8 {
    return .{
        @intCast((input >> 0) & 0xff),
        @intCast((input >> 8) & 0xff),
        @intCast((input >> 16) & 0xff),
        @intCast((input >> 24) & 0xff),
        @intCast((input >> 32) & 0xff),
        @intCast((input >> 40) & 0xff),
        @intCast((input >> 48) & 0xff),
        @intCast((input >> 56) & 0xff),
    };
}

pub fn u8s_to_u64(input: []u8) u64 {
    assert(input.len == 8, "Invalid input");

    const x1 = @as(u64, @intCast(input[0])) << 0;
    const x2 = @as(u64, @intCast(input[1])) << 8;
    const x3 = @as(u64, @intCast(input[2])) << 16;
    const x4 = @as(u64, @intCast(input[3])) << 24;
    const x5 = @as(u64, @intCast(input[4])) << 32;
    const x6 = @as(u64, @intCast(input[5])) << 40;
    const x7 = @as(u64, @intCast(input[6])) << 48;
    const x8 = @as(u64, @intCast(input[7])) << 56;

    return x1 | x2 | x3 | x4 | x5 | x6 | x7 | x8;
}

test "dot and cross" {
    const vec_a = Vec.init(1, 2);
    const vec_b = Vec.init(2, 1);

    const cross = vec_a.cross(vec_b);
    try testing.expectEqual(-3, cross);

    const dot = vec_a.dot(vec_b);
    try testing.expectEqual(4, dot);
}
