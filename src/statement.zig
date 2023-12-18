const lib = @import("lib.zig");
const c = lib.c;
const std = @import("std");
const Allocator = std.mem.Allocator;
const err = lib.CustomErr;
const r = @import("result.zig");

pub const Statement = struct {
    const Self = @This();

    stmt: *c.MYSQL_STMT,
    allocator: Allocator,
    mysql: *c.MYSQL,

    pub fn init(allocator: Allocator,mysql: *c.MYSQL, query: [*c]const u8) !*Self {
        var newSelf = try allocator.create(Self);

        if(lib.prepareStatement(mysql, query)) |ptr| {
            newSelf.stmt = ptr;
            newSelf.allocator = allocator;
            newSelf.mysql = mysql;
            return newSelf;
        } else |er|{
            return er;
        }
    }

    pub fn close(self: *Self) void {
        _ = c.mysql_stmt_close(self.stmt);
        self.allocator.destroy(self);
    }

    pub fn execute(self: *Self, params: anytype) !*r.Result {
        if(lib.fetchResults(self.allocator, self.stmt, params)) |ptr| {
            return ptr;
        } else |e|{
            switch(e){
                error.parameterErr =>{
                    std.debug.panic("Expected number of parameters not met", .{});
                },
                else =>|er| return er
            }
        }
    }

};