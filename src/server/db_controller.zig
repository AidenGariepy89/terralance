const std = @import("std");
const database = @import("../database.zig");

pub fn game_exists(db: *database.DbRef, game_id: u64) !bool {
    db.mutex.lock();
    defer db.mutex.unlock();

    var stmt = try db.db.prepare("select id from game where id = ?");
    defer stmt.deinit();

    const row = try stmt.one(
        struct {
            id: u64,
        },
        .{},
        .{ .id = game_id },
    );

    if (row) |_| {
        return true;
    }

    return false;
}

pub fn player_in_game(db: *database.DbRef, game_id: u64, player_id: u64) !bool {
    db.mutex.lock();
    defer db.mutex.unlock();

    var stmt = try db.db.prepare("select p1, p2, p3, p4 from game where id = ?");
    defer stmt.deinit();

    const row = try stmt.one(
        struct {
            p1: u64,
            p2: u64,
            p3: ?u64,
            p4: ?u64,
        },
        .{},
        .{ .id = game_id },
    );

    if (row) |r| {
        if (r.p1 == player_id) {
            return true;
        }
        if (r.p2 == player_id) {
            return true;
        }
        if (r.p3) |p3| {
            if (p3 == player_id) {
                return true;
            }
        }
        if (r.p4) |p4| {
            if (p4 == player_id) {
                return true;
            }
        }
    }

    return false;
}
