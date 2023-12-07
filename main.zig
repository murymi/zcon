const std = @import("std");
const conn = @import("connection.zig");
const Allocator = std.mem.Allocator;
const pool = @import("pool.zig");

pub fn main() !void {
    _ = Allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const connection = try conn.Connection.newConnection(allocator,.{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" });

    const res = try connection.executeQuery("select * from users", .{});
    _ = res;

    const p = try pool.ConnectionPool.init(allocator,.{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" } , 5);

    const res2 = try p.executeQuery("select * from users", .{});
    std.debug.print("{s}\n",.{res2});
}