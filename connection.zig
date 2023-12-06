const std = @import("std");
const os = std.os;
const Bufflist = @import("bufflist.zig").BuffList;
const ArrayList = std.ArrayList;
const json = std.json;
const writeStream = json.writeStream;
const Allocator = std.mem.Allocator;
const time = std.time;
const lib = @import("lib.zig");

const c = @cImport({
    @cDefine("MAXXY", "500");
    @cInclude("mysql.h");
    @cInclude("stdlib.h");
});

pub const ConnectionConfig = struct {
    host: [*c]const u8,
    username: [*c]const u8,
    password: [*c]const u8,
    databaseName: [*c]const u8,
};

pub const Connection = struct {
    const Self = @This();

    mysql: *c.MYSQL,
    allocator: Allocator,

    pub fn newConnection(allocator: Allocator, config: ConnectionConfig) !*Self {
        var mysql: ?*c.MYSQL = null;
        mysql = c.mysql_init(mysql);
        mysql = c.mysql_real_connect(mysql, config.host, config.username, config.password, config.databaseName, c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);

        try std.testing.expect(mysql != null);

        const newSelf = try allocator.create(Self);
        newSelf.*.allocator = allocator;
        newSelf.*.mysql = mysql.?;

        return newSelf;
    }

    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
        const ms = self.mysql;
        return try lib.executeQuery(@ptrCast(ms), query, parameters);
    }

    pub fn closeConnection(self: *Self) void {
        c.mysql_close(self.mysql);
    }
};
