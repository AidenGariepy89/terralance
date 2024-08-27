const std = @import("std");
const t = std.testing;
const mem = std.mem;
const assert = @import("../assert.zig").assert;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const GameState = @import("../game/game_state.zig").GameState;
const Value = std.atomic.Value;

pub const Arc = struct {
    ref_count: Value(usize),
    drop_fn: *const fn () void,

    pub fn borrow(arc: *Arc) void {
        _ = arc.ref_count.fetchAdd(1, .monotonic);
    }

    pub fn unborrow(arc: *Arc) void {
        assert(arc.ref_count.load(.acquire) > 0, "Need to borrow before you can unborrow!");

        if (arc.ref_count.fetchSub(1, .release) == 1) {
            arc.ref_count.fence(.acquire);
            arc.drop_fn();
        }
    }

    pub fn count(arc: *Arc) usize {
        return arc.ref_count.load(.acquire);
    }

    pub fn noop() void {}
};

test "Arc" {
    var arc = Arc{
        .ref_count = Value(usize).init(0),
        .drop_fn = Arc.noop,
    };

    arc.borrow();
    try t.expect(arc.count() == 1);
    arc.unborrow();
    try t.expect(arc.count() == 0);
}

var test_val: usize = 0;
test "Arc drop fn" {
    const tester = struct {
        fn change() void {
            test_val = 69;
        }
    };

    try t.expect(test_val == 0);

    var arc = Arc{
        .ref_count = Value(usize).init(0),
        .drop_fn = tester.change,
    };

    arc.borrow();
    arc.borrow();
    arc.borrow();
    arc.unborrow();
    arc.unborrow();
    arc.unborrow();

    try t.expect(test_val == 69);
}

pub fn WrappedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]?T = .{null} ** capacity,
        insert_idx: usize = 0,

        pub fn make_room(self: *Self) ?*T {
            assert(self.insert_idx < self.items.len, "Insert idx out of bounds");

            if (self.items[self.insert_idx] == null) {
                return null;
            }

            return &self.items[self.insert_idx].?;
        }

        /// Adds new to items and increments the insertion index
        pub fn add(self: *Self, new: T) *T {
            assert(self.insert_idx < self.items.len, "Insert idx out of bounds");

            self.items[self.insert_idx] = new;
            const ref: *T = &self.items[self.insert_idx].?;

            self.increment_insert_idx();

            return ref;
        }

        /// Invalidates the item at the insertion index, does not increment the insertion index
        pub fn invalidate(self: *Self) void {
            assert(self.insert_idx < self.items.len, "Insert idx out of bounds");

            self.items[self.insert_idx] = null;
        }

        pub fn increment_insert_idx(self: *Self) void {
            self.insert_idx += 1;
            if (self.insert_idx >= self.items.len) {
                self.insert_idx = 0;
            }
        }
    };
}

test "WrappedArray" {
    var arr = WrappedArray(u8, 2){};

    _ = arr.add(5);
    _ = arr.add(10);

    try t.expect(arr.items[0].? == 5);
    try t.expect(arr.items[1].? == 10);

    var released: ?*u8 = arr.make_room();
    try t.expect(released.?.* == 5);

    _ = arr.add(15);
    try t.expect(arr.items[0].? == 15);

    arr.invalidate();
    try t.expect(arr.items[1] == null);

    released = arr.make_room();
    try t.expect(released == null);

    _ = arr.add(20);
    try t.expect(arr.items[1].? == 20);

    arr.increment_insert_idx();
    _ = arr.add(25);
    try t.expect(arr.items[1].? == 25);
}

pub fn NullArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]?T = .{null} ** capacity,

        pub fn add(self: *Self, item: T) error{OutOfSpace}!*T {
            for (0..self.items.len) |i| {
                if (self.items[i] == null) {
                    self.items[i] = item;
                    return &self.items[i].?;
                }
            }

            return error.OutOfSpace;
        }

        pub fn remove(self: *Self, item: *T) error{NotFound}!void {
            const idx = try self.index_of(item);
            self.remove_at(idx);
        }

        pub fn index_of(self: *Self, item: *T) error{NotFound}!usize {
            for (0..self.items.len) |i| {
                if (self.items[i] == null) {
                    continue;
                }

                if (item == &self.items[i].?) {
                    return i;
                }
            }

            return error.NotFound;
        }

        pub fn remove_at(self: *Self, index: usize) void {
            assert(index < self.items.len, "Index out of bounds!");

            self.items[index] = null;
        }
    };
}

test "NullArray" {
    var arr = NullArray(u8, 2){};

    const item1 = arr.add(5) catch unreachable;
    const item2 = arr.add(10) catch unreachable;
    try t.expect(item1.* == 5);
    try t.expect(item2.* == 10);

    const idx1 = arr.index_of(item1) catch unreachable;
    const idx2 = arr.index_of(item2) catch unreachable;
    try t.expect(idx1 == 0);
    try t.expect(idx2 == 1);

    const item3err = arr.add(15);
    try t.expect(item3err == error.OutOfSpace);

    arr.remove(item2) catch unreachable;
    try t.expect(arr.items[1] == null);

    const item3 = arr.add(20) catch unreachable;
    try t.expect(item3.* == 20);
}

pub const CreateGameOptions = struct {
    /// Use 0 if you want a random seed
    seed: u64,
    /// Must be greater than 1
    players: u8,
};

pub const GameManager = struct {
    pub const MaxGames = 8;
    pub const MaxAccesses = 1024;
    pub const GameStateArr = WrappedArray(GameState, MaxGames);
    pub const GameAccessArr = NullArray(GameAccess, MaxAccesses);

    mutex: Mutex = Mutex{},
    games: GameStateArr = GameStateArr{},
    accesses: GameAccessArr = GameAccessArr{},

    pub fn get_game_access(gm: *GameManager, game_id: u64) *GameAccess {
        gm.mutex.lock();
        defer gm.mutex.unlock();

        for (0..gm.accesses.items.len) |i| {
            if (gm.accesses.items[i] == null) {
                continue;
            }

            if (gm.accesses.items[i].?.game_id == game_id) {
                const ref = &gm.accesses.items[i].?;
                ref.arc.borrow();
                return ref;
            }
        }

        return gm.create_access(game_id);
    }

    /// assumes mutex lock
    fn create_access(gm: *GameManager, game_id: u64) *GameAccess {
        const ref = gm.accesses.add(GameAccess.init(game_id, gm)) catch unreachable;
        ref.arc.borrow();
        return ref;
    }

    pub fn remove_access(gm: *GameManager, access: *GameAccess) void {
        gm.mutex.lock();
        gm.accesses.remove(access) catch unreachable;
        gm.mutex.unlock();
    }

    pub fn make_move(gm: *GameManager, game_id: u64, placeholder: ?u32) void {
        gm.mutex.lock();
        defer gm.mutex.unlock();

        for (0..gm.games.items.len) |i| {
            if (gm.games.items[i] == null) {
                continue;
            }

            const ref = &gm.games.items[i].?;
            if (ref.id == game_id) {
                // do stuff here
                _ = placeholder;
                return;
            }
        }

        assert(false, "Loading new game not implemented yet");
    }

    pub fn create_game(gm: *GameManager, settings: GameState.NewGameSettings) *GameAccess {
        gm.mutex.lock();
        defer gm.mutex.unlock();

        if (gm.games.make_room()) |game| {
            game.save_game();
        }

        _ = gm.games.add(GameState.new_game(settings));

        return gm.create_access(settings.id);
    }

    pub fn get_game_references(gm: *GameManager, game_id: u64) usize {
        for (0..gm.accesses.len) |i| {
            if (gm.accesses.items[i] == null) {
                continue;
            }
            const ref = &gm.accesses.items[i].?;

            if (ref.game_id == game_id) {
                return ref.arc.count();
            }
        }
    }
};

pub const GameAccess = struct {
    arc: Arc,
    game_id: u64,
    game_manager: *GameManager,

    pub fn init(game_id: u64, game_manager: *GameManager) GameAccess {
        var access = GameAccess{
            .arc = undefined,
            .game_id = game_id,
            .game_manager = game_manager,
        };

        access.arc = Arc{
            .ref_count = Value(usize).init(0),
            .drop_fn = access.get_remove_fn(),
        };

        return access;
    }

    pub fn return_access(access: *GameAccess) void {
        access.arc.unborrow();
    }

    pub fn remove(access: *GameAccess) void {
        access.game_manager.remove_access(access);
    }

    pub fn get_remove_fn(access: *GameAccess) *const fn () void {
        const impl = struct {
            fn remove() void {
                access.remove();
            }
        };

        return &impl.remove;
    }

    pub fn make_move(access: *GameAccess, placeholder: ?u32) void {
        access.game_manager.make_move(access.game_id, placeholder);
    }
};
