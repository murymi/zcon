const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const ArrayList = std.ArrayList;

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
        return @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast( b.*))))));
    }

    pub fn setBuffer(self :*Self, data: []const u8, pos :usize) !void {
        const tpl = self.getBuffer(pos);

        try expect(tpl.len >= data.len);

        for(data, 0..)|b,i|{
            tpl.*[i] = b;
        }

    }

    pub fn initAndSetBuffer(self: *Self, data: []const u8, pos: usize) !void {
        try self.initBuffer(pos, data.len + 1);
        try self.setBuffer(data, pos);  
    }

    pub fn getBufferAsString(self :*Self,pos :usize) ![]u8 {
        const buff = self.getBuffer(pos);
        return std.mem.sliceTo(buff.*, 0);
    }

    pub fn getInitializedCBuffer(self :*Self, pos: usize) !?*anyopaque{
        const str = try self.getBufferAsString(pos);
        return @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast(str))))));
    }
};
