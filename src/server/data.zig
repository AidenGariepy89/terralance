const std = @import("std");
const t = std.testing;
const assert = @import("../assert.zig").assert;
const GameState = @import("../game/game_state.zig").GameState;
const Thread = std.Thread;
const RwLock = Thread.RwLock;

const GameAccess = struct {
    const Self = @This();

    rc: usize,
    lock: RwLock,
    game_id: u64,
    gm: *GameManager,
};

const GameManager = struct {
    const Self = @This();
    const MaxGames = 4;
    const MaxAccesses = 1024;

    lock: RwLock,
    games: [MaxGames]?GameState,
    accesses: [MaxAccesses]?GameAccess,

    pub fn init() Self {
        return .{
            .lock = RwLock{},
            .games = .{null} ** MaxGames,
            .games_insertion_index = 0,
            .accesses = .{null} ** MaxAccesses,
        };
    }
};
