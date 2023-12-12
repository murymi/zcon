const std = @import("std");
const conn = @import("connection.zig");
const Allocator = std.mem.Allocator;
const pool = @import("pool.zig");

pub fn main() !void {
    _ = Allocator;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const connection = try conn.Connection.newConnection(allocator,.{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" });

    //const res = try connection.executeQuery("select * from users where name = ? and verified = ? and username = ?;", .{"karanja",7, "vic"});
    const statement = try connection.prepare("select * from users where name = ? and verified = ? and username = ?;");
    var res = try statement.execute(.{"karanja",7, "vic"});
    std.debug.print("{s}\n", .{res});

    res = try statement.execute(.{"karanja", "vic"});

    std.debug.print("{s}\n", .{res});

    statement.close();

    //allocator.free(res);
}
