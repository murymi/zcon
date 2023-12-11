const std = @import("std");
const conn = @import("connection.zig");
const Allocator = std.mem.Allocator;
const pool = @import("pool.zig");

pub fn main() !void {
    _ = Allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const connection = try conn.Connection.newConnection(allocator,.{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" });

    const res = try connection.executeQuery("select * from users where name = ? and verified = ? and username = ?;", .{"karanja",0, "vic"});
    std.debug.print("{s}\n", .{res});

    allocator.free(res);
}
