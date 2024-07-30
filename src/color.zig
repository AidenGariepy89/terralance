const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const assert = @import("assert.zig").assert;

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

    pub fn to_raylib(self: RGB) rl.Color {
        return rl.Color{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = 255,
        };
    }
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
