const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

pub const BuffList = struct {
    const Self = @This();

    size: u8,
    allocator: Allocator,
    first: ?*Node,
    last: ?*Node,

    pub const Node = struct {
        data: ?[] u8,
        next: ?*Node,
    };

    pub fn init(allocator: Allocator,size: usize) !*Self{
        const tmp = try allocator.create(Self);

        const ntmp = try allocator.create(Node);

        tmp.*.first = ntmp;
        tmp.*.last = ntmp;
        tmp.*.size = 1;
        tmp.*.allocator = allocator;

        ntmp.*.data = null;
        ntmp.*.next = null;


        for(0..size-1)|_|{
            const bf = try allocator.create(Node);
            bf.*.data = null;
            bf.*.next = null;
            tmp.*.last.?.next = bf;
            tmp.*.size += 1;
            tmp.*.last = bf;
        }

        return tmp;
    }

    pub fn initBuffer(self :*Self, pos :usize,buffsize: usize) !void {
        var ntmpNode = self.first;
        for(0..pos)|_|{
            ntmpNode = ntmpNode.?.next;
        }

        if(ntmpNode.?.data)|d|{
           self.allocator.free(d);
        }
        
        const tmpBuff = try self.allocator.alloc(u8, buffsize);
        @memset(tmpBuff, 0);

        ntmpNode.?.data = tmpBuff;
    }

    pub fn getBuffer(self :*Self, pos :usize) *[]u8 {
    
        var ntmp = self.first;
        for(0..pos) |_| {
            ntmp = ntmp.?.next;
        }

        return &(ntmp.?.data.?);
    }

    pub fn getCBuffer(self :*Self, pos :usize) ?*anyopaque {
        const b = self.getBuffer(pos);
        return @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast( @alignCast( b)))));
    }

    pub fn setBuffer(self :*Self, data: []const u8, pos :usize) !void {
        const tpl = self.getBuffer(pos);

        try expect(tpl.len >= data.len);

        for(data, 0..)|b,i|{
            tpl.*[i] = b;
        }

    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const buffl = try BuffList.init(alloc, 5);

    try buffl.initBuffer(0,10);

    const xbb = buffl.getBuffer(0);
    const xbb2 = buffl.getBuffer(0);

    const xb = buffl.getCBuffer(0);
    _ = xb;

    try buffl.setBuffer("hello", 0);

    try expect(@intFromPtr(xbb) == @intFromPtr(xbb2));

    std.debug.print("{s}",.{xbb2.*});
}