const std = @import("std");
const map = @import("map.zig");
const assert = @import("../assert.zig").assert;
const Map = map.Map;
const Vec = @import("../math.zig").Vec;
const Allocator = std.mem.Allocator;

const MapWidth = 200;

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
    world_map_buf: [MapWidth * MapWidth]map.Tile,

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

    const NewGameSettings = struct {
        seed: ?u64 = null,
        player_count: u8 = 2,
    };

    pub fn new_game(settings: NewGameSettings) Self {
        assert(settings.player_count > 1, "Must have more than one player!");
        assert(settings.player_count < 3, "More than two players not implemented yet!");

        // var file = std.fs.cwd().openFile("output.map", .{}) catch unreachable;
        // defer file.close();
        //
        // var buf_reader = std.io.bufferedReader(file.reader());
        // var reader = buf_reader.reader();
        //
        // var file_buf: [200 * 200 * 5]u8 = undefined;
        // const n = reader.readAll(&file_buf) catch unreachable;

        var buf: [200 * 200]map.Tile = undefined;
        const world_map = Map.generate(200, &buf, settings.seed orelse gen_seed(), .{
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
        // const world_map = Map.decode_rle(file_buf[0..n], &buf);

        var red_player = Player.init();
        const r = Self.player_start_view_radius;
        for ((Self.player_red_start_row - r)..(Self.player_red_start_row + r + 1)) |row| {
            for ((Self.player_red_start_col - r)..(Self.player_red_start_col + r + 1)) |col| {
                const i: usize = (row * MapWidth) + col;
                red_player.world_known.set(i);
            }
        }

        // assert(red_player.world_known.capacity() == world_map.grid.len, "Lengths MUST be the same!");
        // for (0..world_map.grid.len) |i| {
        //     if (red_player.world_known.isSet(i)) {
        //         std.debug.print("1", .{});
        //     } else {
        //         std.debug.print("0", .{});
        //     }
        //     if ((i + 1) % 200 == 0) {
        //         std.debug.print("\n", .{});
        //     }
        // }

        return Self{
            .world_map = world_map,
            .world_map_buf = buf,
            .players = Players{
                .red = red_player,
                .blue = Player.init(),
            },
        };
    }

    /// Type:
    /// 0 -> unknown
    /// 1 -> ground
    /// 2 -> water
    // pub fn client_map_encode(self: *const Self, allocator: Allocator) ![]u8 {
    //     const bytes_per = 5;
    //     const num_tiles = self.world_map.grid.len;
    //     const bytes = bytes_per * num_tiles;
    //
    //     const encoding = try allocator.alloc(u8, bytes);
    //
    //     var i: usize = 0;
    //
    //     while (i < num_tiles) {
    //     }
    //
    //     return encoding;
    // }

    pub fn save_game(self: *const Self) void {
        _ = self;
    }

    pub fn get_client_state(self: *const Self) ClientGameState {
        return .{
            .world_map = self.world_map,
        };
    }

    fn gen_seed() u64 {
        return @intCast(std.time.milliTimestamp());
    }
};
