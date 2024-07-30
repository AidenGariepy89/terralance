//! Game window / screen

const rl = @import("raylib");

pub fn init(width: i32, height: i32) void {
    rl.initWindow(width, height, "Terralance");
    rl.setTargetFPS(60);
}

pub fn deinit() void {
    rl.closeWindow();
}

/// Screen width
pub fn w() i32 {
    return rl.getScreenWidth();
}

/// Screen width
pub fn w_f() f32 {
    return @floatFromInt(rl.getScreenWidth());
}

/// Half screen width
pub fn wh() i32 {
    return @divTrunc(w(), 2);
}

/// Half screen width
pub fn wh_f() f32 {
    return @floatFromInt(@divTrunc(w(), 2));
}

/// Screen height
pub fn h() i32 {
    return rl.getScreenHeight();
}

/// Screen height
pub fn h_f() f32 {
    return @floatFromInt(rl.getScreenHeight());
}

/// Half screen height
pub fn hh() i32 {
    return @divTrunc(h(), 2);
}

/// Half screen height
pub fn hh_f() f32 {
    return @floatFromInt(@divTrunc(h(), 2));
}

pub fn shouldClose() bool {
    return rl.windowShouldClose();
}
