const std = @import("std");
const t = std.testing;

pub const Vec = struct {
    x: f32,
    y: f32,

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
};

test "dot and cross" {
    const vec_a = Vec.init(1, 2);
    const vec_b = Vec.init(2, 1);

    const cross = vec_a.cross(vec_b);
    try t.expectEqual(-3, cross);

    const dot = vec_a.dot(vec_b);
    try t.expectEqual(4, dot);
}
