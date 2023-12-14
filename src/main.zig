const std = @import("std");
const conn = @import("connection.zig");
const Allocator = std.mem.Allocator;
const pool = @import("pool.zig");
const config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };

test "test" {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = std.testing.allocator;
    //gpa.allocator();
    const connection = try conn.Connection.newConnection(allocator, config);
    defer connection.close();


    const statement = try connection.prepare("select * from users");
    defer statement.close();

    const tm = std.time.Timer;
    var start = try tm.start();
    const res2 = try statement.execute(.{});
    const end = start.read();
    
    if(res2.nextResultSet()) |re| {
        while(re.nextRow()) |ro| {
        
            std.debug.print("{any}\n", .{ro.columns});
        }

    }

    res2.deinit();
    std.debug.print("Taken {}ms\n", .{end/1000000});

}
