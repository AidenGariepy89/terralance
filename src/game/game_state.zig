const std = @import("std");
const map = @import("map.zig");
const utils = @import("../utils.zig");
const assert = @import("../assert.zig").assert;
const Map = map.Map;
const Vec = @import("../math.zig").Vec;
const Allocator = std.mem.Allocator;

const MapWidth = Map.GridWidth;

pub const Player = struct {
    const BitSet = std.bit_set.ArrayBitSet(u8, MapWidth * MapWidth);

    world_known: BitSet,

    pub fn init() Player {
        return Player{
            .world_known = BitSet.initEmpty(),
        };
    }
};

pub const ClientGameState = struct {
    world_map: Map,
};

pub const GameState = struct {
    const Self = @This();

    id: u64,

    world_map: Map,

    players: Players,

    const Players = struct {
        red: Player,
        blue: Player,
    };
    const player_red_start_row: u32 = 50;
    const player_red_start_col: u32 = 100;
    const player_blue_start_row: u32 = 150;
    const player_blue_start_col: u32 = 100;
    const player_start_view_radius: u32 = 16;

    pub const MaxPlayers = 4;

    pub const NewGameSettings = struct {
        id: u64,
        seed: u64,
        player_count: u8 = 2,
    };

    pub fn new_game(settings: NewGameSettings) Self {
        assert(settings.player_count > 1, "Must have more than one player!");
        assert(settings.player_count < 3, "More than two players not implemented yet!");

        const world_map = Map.generate(settings.seed, .{
            .sea_level = 0.18,

            .continent_noise_min = -0.0043,
            .continent_noise_max = 0.005,
            .continent_octaves = 5,
            .continent_resolution = 0.012,

            .temperature_noise_min = -0.005,
            .temperature_noise_max = 0.0045,
            .temperature_octaves = 2,
            .temperature_resolution = 0.02,
        });

        var red_player = Player.init();
        const r = Self.player_start_view_radius;
        for ((Self.player_red_start_row - r)..(Self.player_red_start_row + r + 1)) |row| {
            for ((Self.player_red_start_col - r)..(Self.player_red_start_col + r + 1)) |col| {
                const i: usize = (row * MapWidth) + col;
                red_player.world_known.set(i);
            }
        }

        // var cwd = std.fs.cwd();
        // cwd.deleteFile("client.map") catch |err| switch (err) {
        //     std.fs.Dir.DeleteFileError.FileNotFound => {},
        //     else => unreachable,
        // };
        // var file = cwd.createFile("client.map", .{}) catch unreachable;
        // defer file.close();
        // const writer = file.writer();
        //
        // var encode_buf: [200 * 200 * 5]u8 = undefined;
        // const n = world_map.encode_rle_client(&encode_buf, &red_player.world_known);
        //
        // writer.writeAll(encode_buf[0..n]) catch unreachable;

        return Self{
            .id = settings.id,
            .world_map = world_map,
            .players = Players{
                .red = red_player,
                .blue = Player.init(),
            },
        };
    }

    pub fn save_game(self: *const Self) void {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{}/{}{}", .{utils.SaveDirRelPath, self.id, utils.SaveFileType}) catch unreachable;

        var save_file = std.fs.cwd().createFile(path, .{}) catch unreachable;
        defer save_file.close();

        var map_buf: [MapWidth * MapWidth * Map.RLEPacketLength]u8 = undefined;
        const n = self.world_map.encode_rle(&map_buf);

        save_file.writeAll(map_buf[0..n]) catch unreachable;
    }

    pub fn load_game(game_id: u64) Self {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{}/{}{}", .{utils.SaveDirRelPath, game_id, utils.SaveFileType}) catch unreachable;

        var save_file = std.fs.cwd().openFile(path, .{}) catch unreachable;
        defer save_file.close();

        var buf: [MapWidth * MapWidth * Map.RLEPacketLength]u8 = undefined;
        const n = save_file.readAll(&buf) catch unreachable;

        return Map.decode_rle(buf[0..n], false);
    }

    pub fn get_client_state(self: *const Self) ClientGameState {
        _ = self;

        var read_file = std.fs.cwd().openFile("client.map", .{}) catch unreachable;
        defer read_file.close();
        const reader = read_file.reader();

        var read_buf: [200 * 200 * 5]u8 = undefined;
        const n = reader.readAll(&read_buf) catch unreachable;

        const world_map = Map.decode_rle(read_buf[0..n], true);

        return .{
            .world_map = world_map,
        };
    }
};
