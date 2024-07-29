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

/// Half screen width
pub fn wh() i32 {
    return @divTrunc(w(), 2);
}

/// Screen height
pub fn h() i32 {
    return rl.getScreenHeight();
}

/// Half screen height
pub fn hh() i32 {
    return @divTrunc(h(), 2);
}

pub fn shouldClose() bool {
    return rl.windowShouldClose();
}
