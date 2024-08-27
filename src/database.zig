const std = @import("std");
const sqlite = @import("sqlite");

pub const Db = sqlite.Db;
pub const DbRef = struct {
    mutex: std.Thread.Mutex,
    db: *Db,
};

const db_name = "db/terralance.db";

pub fn init_db() !Db {
    var db_exists = true;
    _ = std.fs.cwd().statFile(db_name) catch |err| switch (err) {
        error.FileNotFound => {
            db_exists = false;
        },
        else => return err,
    };

    var buf: [1024]u8 = undefined;
    const cwd_path = try std.fs.cwd().realpath(".", &buf);
    const path = try std.fmt.bufPrintZ(buf[cwd_path.len..], "{s}/{s}", .{ cwd_path, db_name });

    std.debug.print("{s} | {}\n", .{ path, db_exists });

    const db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = path },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });

    return db;
}
