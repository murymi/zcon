const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib.zig");
const ConnectionConfig = lib.ConnectionConfig;

const c = lib.c;

pub const Connection = struct {
    const Self = @This();

    mysql: *c.MYSQL,
    allocator: Allocator,

    pub fn newConnection(allocator: Allocator, config: ConnectionConfig) !*Self {
        const newSelf = try allocator.create(Self);
        newSelf.allocator = allocator;
        newSelf.mysql = try lib.initConnection(config);

        return newSelf;
    }

    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
        const ms = self.mysql;
        return try lib.executeQuery(self.allocator,ms, query, parameters);
    }

    pub fn closeConnection(self: *Self) void {
        c.mysql_close(self.mysql);
        self.allocator.destroy(self);
    }
};

test "mem leak" {
    const config: ConnectionConfig = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
    const conn = try Connection.newConnection(std.testing.allocator, config);
    const res = try conn.executeQuery("select * from users where name = ?", .{"karanja"});
    _ = res;
    defer conn.closeConnection();
}
