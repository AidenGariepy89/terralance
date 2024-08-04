const std = @import("std");
const rl = @import("raylib");
const w = @import("../window.zig");
const ui = @import("ui.zig");
const assert = @import("../assert.zig").assert;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Vec2 = rl.Vector2;
const ClientGameState = @import("../game/game.zig").ClientGameState;

pub const ClientRequest = union(enum) {
    new_game: void,
    quit: ClientError!void,
};

pub const ClientError = error{
    uhoh,
};

/// Raylib client implementation
pub const Client = struct {
    const Self = @This();
    const Screen = enum {
        title,
        game,
    };

    cgs: ?ClientGameState,
    screen: Screen,
    font: rl.Font,

    world_texture: ?rl.Texture2D,

    pub fn init() Self {
        w.init(800, 600);

        return Self{
            .cgs = null,
            .screen = .title,
            .font = rl.getFontDefault(),

            .world_texture = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.world_texture) |txtr| {
            txtr.unload();
        }

        w.deinit();
        self.* = undefined;
    }

    pub fn update(self: *Self) ?ClientRequest {
        if (w.shouldClose()) {
            return .{ .quit = {} };
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        switch (self.screen) {
            .title => {
                const result = self.title_screen();
                if (result) |req| {
                    return req;
                }
            },
            .game => {
                self.render_game();
            },
        }

        return null;
    }

    fn title_screen(self: *Self) ?ClientRequest {
        const spacing = 100;

        const title_text = "TERRALANCE";
        const title_font_size = 45;
        const title_spacing = 3;
        const title_measure = rl.measureTextEx(self.font, title_text, title_font_size, title_spacing);
        const title_position = Vec2.init(
            w.wh_f() - title_measure.x / 2,
            w.hh_f() - title_measure.y / 2 - spacing,
        );

        rl.drawTextEx(self.font, title_text, title_position, title_font_size, title_spacing, rl.Color.white);

        const button_w = 200;
        const button_h = 50;
        const button_center = Vec2.init(w.wh_f(), w.hh_f() + spacing / 2);
        const button_bounds = rl.Rectangle.init(button_center.x - button_w / 2, button_center.y - button_h / 2, button_w, button_h);
        const button_border = 3;
        const button_text = "New Game";
        const button_font_size = 20;
        const button_spacing = title_spacing;
        const button_text_measure = rl.measureTextEx(self.font, button_text, button_font_size, button_spacing);
        const button_text_position = Vec2.init(
            button_center.x - button_text_measure.x / 2,
            button_center.y - button_text_measure.y / 2,
        );

        const mouse_position = rl.getMousePosition();
        if (rl.checkCollisionPointRec(mouse_position, button_bounds)) {
            rl.drawRectangleRec(button_bounds, rl.Color.init(255, 255, 255, 80));

            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                self.screen = .game;

                return ClientRequest{ .new_game = {} };
            }
        }
        rl.drawRectangleLinesEx(button_bounds, button_border, rl.Color.white);
        rl.drawTextEx(self.font, button_text, button_text_position, button_font_size, button_spacing, rl.Color.white);

        return null;
    }

    fn render_game(self: *Self) void {
        assert(self.cgs != null, "Client should have game state at this point!");
        const cgs = self.cgs.?;

        if (self.world_texture == null) {
            self.world_texture = cgs.world_map.visualize();
        }
        const map_wh: i32 = @intCast(cgs.world_map.width() / 2);
        self.world_texture.?.draw(w.wh() - map_wh, w.hh() - map_wh, rl.Color.white);
    }
};
