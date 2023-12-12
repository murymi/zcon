const std = @import("std");
const conn = @import("connection.zig");
const Allocator = std.mem.Allocator;
const pool = @import("pool.zig");
const config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const connection = try conn.Connection.newConnection(allocator, config);
    defer connection.close();

    const res = try connection.executeQuery("select * from users where name = ?", .{"karanja"});
    std.debug.print("{s}\n", .{res});

    const statement = try connection.prepare("call insert_user(?,?,?)");
    defer statement.close();
    const res2 = try statement.execute(.{"kamau", "nigggahhg", "yeah brohg"});

    std.debug.print("{s}\n", .{res2});
}
