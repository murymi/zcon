const lib = @import("lib.zig");
const c = lib.c;
const Allocator = @import("std").mem.Allocator;

pub const Statement = struct {
    const Self = @This();

    stmt: *c.MYSQL_STMT,
    allocator: Allocator,

    pub fn init(allocator: Allocator,mysql: *c.MYSQL, query: [*c]const u8) !*Self {
        var newSelf = try allocator.create(Self);
        newSelf.stmt = try lib.prepareStatement(mysql, query);
        newSelf.allocator = allocator;
        return newSelf;
    }

    pub fn close(self: *Self) void {
        c.mysql_stmt_close(self.stmt);
        self.allocator.destroy(self);
    }

    pub fn execute(self: *Self, params: anytype) ![]u8 {
        return lib.fetchResults(self.allocator, self.stmt, params);
    }

};