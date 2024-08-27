const std = @import("std");
const t = std.testing;
const net = std.net;
const mem = std.mem;
const log = std.log;
const math = @import("math.zig");
const database = @import("database.zig");
const game_state = @import("game/game_state.zig");
const server_data = @import("server/data.zig");
const assert = @import("assert.zig").assert;
const Thread = std.Thread;
const GameState = game_state.GameState;
const Connection = net.Server.Connection;
const Mutex = Thread.Mutex;

pub const Arc = server_data.Arc;
pub const WrappedArray = server_data.WrappedArray;
pub const NullArray = server_data.NullArray;
pub const GameManager = server_data.GameManager;
pub const GameAccess = server_data.GameAccess;
pub const CreateGameOptions = server_data.CreateGameOptions;

// const GamePool = struct {
//     const MaxGames = 2;
//     const MaxAccesses = 1024;
//
//     mutex: Mutex = Mutex{},
//     games: [MaxGames]?GameState = .{null} ** MaxGames,
//     accesses: [MaxAccesses]?GameAccess = .{null} ** MaxAccesses,
//     games_idx: usize = 0,
//     accesses_idx: usize = 0,
//
//     fn create_game(pool: *GamePool, settings: GameState.NewGameSettings) *GameAccess {
//         pool.mutex.lock();
//         defer pool.mutex.unlock();
//
//         // save last game if exists
//
//         pool.games[pool.games_idx] = GameState.new_game(settings);
//
//         const game = &pool.games[pool.games_idx].?;
//         
//         pool.games_idx += 1;
//         if (pool.games_idx >= MaxGames) {
//             pool.games_idx = 0;
//         }
//
//         pool.accesses[pool.accesses_idx] = GameAccess{
//             .mutex = Mutex{},
//             .game = game,
//             .game_id = settings.id,
//             .ref_count = 0,
//             .pool = pool,
//             .index = pool.accesses_idx,
//         };
//
//         const access = &pool.accesses[pool.accesses_idx].?;
//
//         pool.accesses_idx += 1;
//         if (pool.accesses_idx >= MaxAccesses) {
//             pool.accesses_idx = 0;
//         }
//
//         return access;
//     }
//
//     fn load_game(pool: *GamePool, game_id: u64) *GameAccess {
//         for (0..pool.games.len) |i| {
//             if (pool.games[i] == null) {
//                 continue;
//             }
//
//             if (pool.games[i].?.id != game_id) {
//                 continue;
//             }
//
//             pool.accesses[pool.accesses_idx] = GameAccess{
//                 .mutex = Mutex{},
//                 .game = &pool.games[i].?,
//                 .game_id = game_id,
//                 .ref_count = 0,
//                 .pool = pool,
//                 .index = i,
//             };
//
//             const access = &pool.accesses[pool.accesses_idx].?;
//
//             pool.accesses_idx += 1;
//             if (pool.accesses_idx >= MaxAccesses) {
//                 pool.accesses_idx = 0;
//             }
//
//             return access;
//         }
//
//         assert(false, "Expected a game to already be loaded");
//     }
//
//     fn remove_access(pool: *GamePool, access: *GameAccess) void {
//         access.mutex.unlock();
//
//         pool.mutex.lock();
//         defer pool.mutex.unlock();
//
//         pool.accesses[access.index] = null;
//     }
// };
//
// const GameAccess = struct {
//     mutex: Mutex,
//
//     game: ?*GameState,
//     game_id: u64,
//     ref_count: usize,
//
//     pool: *GamePool,
//     index: usize,
//
//     fn add_ref(access: *GameAccess) void {
//         access.mutex.lock();
//         defer access.mutex.unlock();
//
//         access.ref_count += 1;
//     }
//
//     /// To avoid undefined behavior, do not use the GameAccess after calling this function
//     fn remove_ref(access: *GameAccess) void {
//         access.mutex.lock();
//
//         if (access.ref_count != 0) {
//             access.ref_count -= 1;
//         }
//
//         if (access.ref_count == 0) {
//             // mutex must be unlocked in access.pool
//             access.pool.remove_access(access);
//         } else {
//             access.mutex.unlock();
//         }
//     }
// };

const ThreadData = struct {
    db: *database.Db,
    conn: Connection,
    game_manager: *GameManager,
};

const HandshakePacket = struct {
    player_id: u64,
    game_id: u64,
};

const test_handshake = HandshakePacket{
    .player_id = 1,
    .game_id = 1,
};

pub fn server() !void {
    var db = try database.init_db();

    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, 4000);

    var s = try addr.listen(.{});
    log.info("[server] running", .{});

    var gm = GameManager{};

    while (true) {
        const conn = try s.accept();
        _ = try Thread.spawn(.{}, connection_accepted, .{ThreadData{
            .db = &db,
            .conn = conn,
            .game_manager = &gm,
        }});
    }
}

const InitMode = enum { create, load };

fn connection_accepted(data: ThreadData) void {
    log.info("[server] connection ({}) accepted", .{data.conn.address});
    defer log.info("[server] connection ({}) closed", .{data.conn.address});

    const handshake = connection_handshake(&data.conn) catch |err| {
        log.err("[server] connection ({}) read error: {}", .{ data.conn.address, err });

        data.conn.stream.writeAll("err\n") catch {};
        data.conn.stream.close();

        return;
    };

    var mode: InitMode = .load;

    if (handshake.game_id == 0) {
        mode = .create;
    }

    data.conn.stream.writeAll("ready\n") catch |err| {
        log.err("[server] connection ({}) write error: {}", .{ data.conn.address, err });
        data.conn.stream.close();
        return;
    };
    log.info("[server] sent handshake to connection ({})", .{data.conn.address});

    const access = switch (mode) {
        .create => create_game(data.db, &data.conn) catch |err| {
            log.err("[server] create game error: {}", .{err});

            data.conn.stream.writeAll("err\n") catch {};
            data.conn.stream.close();

            return;
        },
        .load => load_game(data.db, &data.conn) catch |err| {
            log.err("[server] load game error: {}", .{err});

            data.conn.stream.writeAll("err\n") catch {};
            data.conn.stream.close();

            return;
        },
    };

    _ = access;

    data.conn.stream.close();
}

fn connection_handshake(conn: *const Connection) !HandshakePacket {
    const reader = conn.stream.reader();

    var buf: [16]u8 = undefined;

    for (0..buf.len) |i| {
        const c = try reader.readByte();
        buf[i] = c;
    }

    return .{
        .player_id = math.u8s_to_u64(buf[0..8]),
        .game_id = math.u8s_to_u64(buf[8..]),
    };
}

const CreateGameError = error{
    SqlStatementError,
    SqlExecutionError,
};

fn create_game(data: *ThreadData) !*GameAccess {
    const reader = data.conn.stream.reader();

    var buf: [9]u8 = undefined;

    for (0..buf.len) |i| {
        const c = try reader.readByte();
        buf[i] = c;
    }

    var settings = GameState.NewGameSettings{
        .id = 0,
        .seed = math.u8s_to_u64(buf[0..8]),
        .player_count = buf[8],
    };

    var game_count_stmt = data.db.prepare("select max(id) as id from game") catch {
        return CreateGameError.SqlStatementError;
    };
    defer game_count_stmt.deinit();

    const row = game_count_stmt.one(
        struct {
            id: u64,
        },
        .{},
        .{},
    ) catch return CreateGameError.SqlExecutionError;
    assert(row != null, "Database did not return result");

    settings.id = row.?.id + 1;

    var save_path_buf: [512]u8 = undefined;
    const cwd_path = try std.fs.cwd().realpath(".", &save_path_buf);
    const save_path: [:0]u8 = try std.fmt.bufPrintZ(save_path_buf[cwd_path.len..], "{s}/saves/{}.map", .{ cwd_path, settings.id });

    const seed: u64 = if (settings.seed == 0) @intCast(std.time.milliTimestamp()) else settings.seed;

    var create_game_stmt = data.db.prepare("insert into game(id, save_path, seed, players) values(?, ?, ?, ?)") catch {
        return CreateGameError.SqlStatementError;
    };
    defer create_game_stmt.deinit();

    create_game_stmt.exec(.{}, .{
        .id = settings.id,
        .save_path = save_path,
        .seed = seed,
        .players = settings.players,
    }) catch return CreateGameError.SqlExecutionError;

    return data.game_manager.create_game(settings);
}

fn load_game(db: *database.Db, conn: *const Connection) !GameAccess {
    _ = db;

    const reader = conn.stream.reader();

    while (true) {
        const c = try reader.readByte();
        log.debug("{}", .{c});
    }

    return error.NotImplementedYet;
}

pub fn client() !void {
    const addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, 4000);

    const stream = try net.tcpConnectToAddress(addr);
    defer stream.close();

    log.info("[client] connected", .{});

    // random sleep for testing
    var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = rng.random();
    std.time.sleep(random.intRangeAtMost(u64, 1_000_000_000, 3_000_000_000));

    const writer = stream.writer();
    const reader = stream.reader();

    var handshake_packet: [16]u8 = undefined;
    const player_id = math.u64_to_u8s(test_handshake.player_id);
    const game_id = math.u64_to_u8s(test_handshake.game_id);
    mem.copyForwards(u8, &handshake_packet, &player_id);
    mem.copyForwards(u8, handshake_packet[8..], &game_id);

    try writer.writeAll(&handshake_packet);

    var buf: [2048]u8 = undefined;
    const handshake = try reader.readUntilDelimiter(&buf, '\n');

    assert(mem.eql(u8, handshake, "ready"), "Unexpected server error");

    log.info("[client] handshake successful", .{});

    // const data = CreateGameOptions{
    //     .seed = 69420,
    //     .players = 2,
    // };
    // var create_game_packet: [9]u8 = undefined;
    // const seed = math.u64_to_u8s(data.seed);
    // mem.copyForwards(u8, &create_game_packet, &seed);
    // create_game_packet[8] = data.players;
    //
    // try writer.writeAll(&create_game_packet);

    std.time.sleep(5_000_000_000);

    try writer.writeAll("Hello there");
}

test {
    _ = server_data;
}
