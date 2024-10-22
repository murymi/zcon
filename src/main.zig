const stdy = @import("std");
const conn = @import("connection.zig");
const Allocator = stdy.mem.Allocator;
const pool = @import("pool.zig");
const config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
const json = stdy.json;

test "test" {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = stdy.testing.allocator;
    //gpa.allocator();
    //const connection = try conn.Connection.newConnection(allocator, config);
    //defer connection.close();

    
    const pl = try pool.ConnectionPool.init(allocator, config, 5);
    defer pl.deInit();
    //const statement = try connection.prepare("select * from users;");
    //defer statement.close();

    const connection = pl.getConnection();

    _ = connection.changeUser(.{ .username = "vic", .database = "events", .password = "1234Victor"});
    _ = connection.setAutoCommitMode(false);
    _ = connection.getAffectedRows();
    const charset = connection.getCharacterSetName();
    _ = connection.rollBack();
    _ = connection.reset();
    _= connection.ping();
    //const tm = std.time.Timer;
    //var start = try tm.start();
    //const res2 = try statement.execute(.{});
    //const res = try connection.executeQuery("select * from users limit ?",.{5});
    //const end = start.read();
    //
    //while(res.nextResultSet()) |re| {
    //    while(re.nextRow()) |ro| {
    //        const d = try ro.columns.?.toString();
    //        defer allocator.free(d);
    //        std.debug.print("{s}\n", .{d});
    //    }
//
    //}
//
    //res.deinit();
    stdy.debug.print("Taken {s} ms\n", .{charset});

}

pub fn main () !void {
    var gpa = stdy.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const pl = try pool.ConnectionPool.init(allocator, config, 5);
    defer pl.deInit();
   // _= pl;
    stdy.debug.print("hello world\n", .{});
}
