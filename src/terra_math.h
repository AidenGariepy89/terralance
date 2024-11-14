#ifndef TERRA_MATH_H
#define TERRA_MATH_H

#include "raylib.h"
#include <cstdint>


/*

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
*/


class PerlinNoise {
    uint8_t _permutations;

public:

    PerlinNoise();

    /// Fractal Brownian Motion
    float fbm(float x, float y, int octaves);
    float noise_2d(float x, float y);

private:
    int inc_with_wrap(int x);
    Vector2 perm_hash(uint8_t hash);
    float ease(float x);
};






/// Returns a percentage of the progress of val from min to max.
/// 
/// If val is less than min, returns 0.
/// If val is greater than max, returns 1.
float progress(float min, float max, float val);
/// Cubic bezier.
Vector2 cubic_bezier(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, float t);






#endif
