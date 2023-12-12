const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib.zig");
const ConnectionConfig = lib.ConnectionConfig;
const Statement = @import("statement.zig").Statement;

const c = lib.c;

//Single DB connection
pub const Connection = struct {
    const Self = @This();

    // C type Connection struct
    mysql: *c.MYSQL,

    allocator: Allocator,

    dirty: bool,

    // Creates a connection
    pub fn newConnection(allocator: Allocator, config: ConnectionConfig) !*Self {
        const newSelf = try allocator.create(Self);
        newSelf.allocator = allocator;
        newSelf.dirty = false;
        newSelf.mysql = try lib.initConnection(config);

        return newSelf;
    }

    // Execute query. Returns result in json format
    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
        const ms = self.mysql;
        self.dirty = true;
        return try lib.executeQuery(self.allocator,ms, query, parameters);
    }

    pub fn close(self: *Self) void {
        c.mysql_close(self.mysql);
        self.allocator.destroy(self);
    }

    // Create prepared statement
    pub fn prepare(self: *Self, query: [*c]const u8) !*Statement {
        //if(self.dirty) return error.connectionDirty;
        return try Statement.init(self.allocator,self.mysql, query);
    }
};

test "mem leak" {
    const config: ConnectionConfig = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
    const conn = try Connection.newConnection(std.testing.allocator, config);
    const res = try conn.executeQuery("select * from users where name = ?", .{"karanja"});
    defer std.testing.allocator.free(res);
    defer conn.close();
}
