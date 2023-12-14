const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const ArrayList = std.ArrayList;

//This is a list to hold buffers when binding parameters and results
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

    // create new list of buffers
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

    //resize buffer to size buffsize
    pub fn initBuffer(self :*Self, pos :usize,buffsize: usize) !void {
        try expect(self.size > pos);
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

    //Get Z type buffer at pos
    pub fn getBuffer(self :*Self, pos :usize) ?*[] u8 {

        if(self.size < pos){
            return null;
        }

        var ntmp = self.first;
        for(0..pos) |_| {
            ntmp = ntmp.?.next;
        }

        const a = ntmp.?.data;
        if(a) |ptr|{
            return @constCast(&ptr);
        }else {
            return null;
        }
    }

    //get C type buffer at pos
    pub fn getCBuffer(self :*Self, pos :usize) ?*anyopaque {
        if(self.getBuffer(pos)) |val| {
            return @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast( val.*))))));
        } else {
            return null;
        }
    }

    //copy string data to buffer at pos
    pub fn setBuffer(self :*Self, data: []const u8, pos :usize) !void {
        const tpl = self.getBuffer(pos);

        if(tpl)|val| {
            try expect(val.len >= data.len);

            for(data, 0..)|b,i|{
                val.*[i] = b;
            }
        }

    }

    //Resize and set Buffer
    pub fn initAndSetBuffer(self: *Self, data: []const u8, pos: usize) !void {
        try self.initBuffer(pos, data.len + 1);
        try self.setBuffer(data, pos);  
    }

    /// Get buffer as Zig string
    pub fn getBufferAsString(self :*Self,pos :usize) ?[] u8 {
        const buff = self.getBuffer(pos);
        if(buff) |val| {
            return std.mem.sliceTo(val.*, 0);
        }

        return null;
    }

    //Get buffer casted to C string
    pub fn getInitializedCBuffer(self :*Self, pos: usize) !?*anyopaque{
        const str = try self.getBufferAsString(pos);
        return @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast(str))))));
    }

    //clean up
    pub fn deInit(self: *Self) void {
        var x = self.first;
        for(0..self.size)|_|{
            const y = x.?;
            x = y.next;
            if(y.data) |ptr| {
                self.allocator.free(ptr);
            }
            self.allocator.destroy(y);
        }

        self.allocator.destroy(self);
    }

    pub fn clone(self: *Self) !*Self {
        const cp = try Self.init(self.allocator, self.size);

        for(0..self.size)|i|{

            if(self.getBufferAsString(i))|val|{
                try cp.initAndSetBuffer(val, i);
            }
        }

        return cp;
    }
};


test "buff" {
    const x = try BuffList.init(std.testing.allocator, 3);
    try x.initAndSetBuffer("hello world", 2);

    const str = x.getBufferAsString(2);
    var cstr = @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast(str.?))))));

    cstr = @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast("hello"))))));

    const clone = try x.clone();
    defer clone.deInit();

    const str2 = clone.getBufferAsString(2);

    try expect(std.mem.eql(u8, str.?,str2.?));


    defer x.deInit();
}