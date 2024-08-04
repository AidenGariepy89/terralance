const std = @import("std");
const map = @import("map.zig");
const Map = map.MapNormal;

pub const ClientGameState = struct {
    world_map: Map,
};

pub const GameState = struct {
    const Self = @This();

    world_map: Map,

    pub fn new_game(seed: ?u64) Self {
        const world_map = Map.generate(seed orelse gen_seed(), .{
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

        return Self{
            .world_map = world_map,
        };
    }

    pub fn get_client_state(self: Self) ClientGameState {
        return .{
            .world_map = self.world_map,
        };
    }

    fn gen_seed() u64 {
        return @intCast(std.time.milliTimestamp());
    }
};
