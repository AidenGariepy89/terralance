const std = @import("std");

pub fn csv_stdout(T: type, items: []T) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    for (items) |item| {
        try stdout.print("{},", .{item});
    }
    try bw.flush();
}
