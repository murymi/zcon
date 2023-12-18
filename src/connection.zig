const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib.zig");
const ConnectionConfig = lib.ConnectionConfig;
const Statement = @import("statement.zig").Statement;
const r = @import("result.zig");

const c = lib.c;

//Single DB connection
pub const Connection = struct {
    const Self = @This();

    // C type Connection struct
    mysql: *c.MYSQL,

    allocator: Allocator,

    dirty: bool,

    next: ?*Self,

    idle: bool,

    // Creates a connection
    pub fn newConnection(allocator: Allocator, config: ConnectionConfig) !*Self {
        const newSelf = try allocator.create(Self);
        newSelf.allocator = allocator;
        newSelf.dirty = false;
        newSelf.next = null;
        newSelf.idle = true;
        newSelf.mysql = try lib.initConnection(config);

        return newSelf;
    }

    // Execute query. Returns result in json format
    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) !*r.Result {
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

    /// Returns the number of rows changed, deleted, or
    /// inserted by the last statement if it was an UPDATE, DELETE, or INSERT. For SELECT statements,
    /// it returns number of rows fetched.
    pub fn getAffectedRows(self: *Self) u64 {
        return c.mysql_affected_rows(self.mysql);
    }

    /// Sets autocommit mode on if mode is true, off if mode is false.
    /// returns true for success
    pub fn setAutoCommitMode(self: *Self, mode: bool) bool {
        return c.mysql_autocommit(self.mysql, mode);
    }

    /// Changes the user and causes the database specified by db to become the default (current) database
    /// on the connection specified. 
    /// Zero for success. Nonzero if an error occurred.
    pub fn changeUser(self: *Self, user: lib.User) bool {
        return c.mysql_change_user(self.mysql, user.username, user.password, user.database orelse null);
    }

    /// Returns the default character set name for the current connection.
    pub fn getCharacterSetName(self: *Self) [*c]const u8 {
        return c.mysql_character_set_name(self.mysql);
    }

    /// Commits the current transaction.
    /// Zero for success
    pub fn commit(self: *Self) bool {
        return c.mysql_commit(self.mysql);
    }

    pub fn errNo(self: *Self) void {
        _ = self;
    

    }
};

test "mem leak" {
    //const config: ConnectionConfig = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
    //const conn = try Connection.newConnection(std.testing.allocator, config);
    //const res = try conn.executeQuery("select * from users where name = ?", .{"karanja"});
    //defer std.testing.allocator.free(res);
    //defer conn.close();
}
