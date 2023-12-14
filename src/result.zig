const std = @import("std");
const ArrayList = @import("lib.zig").Bufflist;
const Allocator = std.mem.Allocator;

pub const Row = struct {
    const Self = @This();

    nextRow: ?*Row,
    columns: ?*ArrayList,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*Self {
        const r = try allocator.create(Self);
        r.* = .{ .nextRow = null, .columns = null, .allocator = allocator };

        return r;
    }

    pub fn deInit(self: *Self) void {
        if(self.columns) |c| {
            c.deInit();
        }

        self.allocator.destroy(self);
    }
};

pub const ResultSet = struct {
    const Self = @This();

    nextSet: ?*Self,
    firstRow: ?*Row,
    currentRow: ?*Row,

    allocator: Allocator,

    pub fn init(allocator: Allocator) !*Self {
        const rs = try allocator.create(Self);
        rs.* = .{ .nextSet = null, .firstRow = null,  .allocator = allocator , .currentRow = null };
        return rs;
    }

    pub fn insertRow(self: *Self, row: *Row) void {
    
        var fr = self.firstRow;

        if(fr) |_| {} else {
            self.firstRow = row;
            self.currentRow = row;
            return;
        }

        while(fr.?.nextRow) |ptr| {
            fr = ptr;
        } else {
            fr.?.nextRow = row;
        }
    }

    pub fn deInit(self: *Self) void {
        var fr = self.firstRow;

        while(fr) |ptr| {
            fr = ptr.nextRow;
            ptr.deInit();
        }

        self.allocator.destroy(self);
    }

    pub fn nextRow(self: *Self) ?*Row {
        if(self.currentRow)|ptr| {
           self.currentRow = ptr.nextRow orelse null;
            return ptr;
        }

        return null;
    }
};

pub const Result = struct {
    const Self = @This();

    resultSets: ?*ResultSet,
    firstSet: ?*ResultSet,
    allocator: Allocator,
    nextRSet: ?*ResultSet,

    pub fn init(allocator: Allocator) !*Self {
        const r = try allocator.create(Self);

        r.* = .{
            .resultSets = null,
            .firstSet = null,
            .nextRSet = null,
            .allocator = allocator
        };

        return r;
    }

    pub fn insert(self: *Self, set: *ResultSet) void {
        if(self.firstSet) |_|{} else {
            self.firstSet = set;
            self.nextRSet = set;
            return;
        }

        var fs = self.firstSet;

        while(fs.?.nextSet)|ptr|{
                fs = ptr;
        } else {
                fs.?.nextSet = set;
        }
    }

    pub fn deinit(self: *Self) void {
        var fs = self.firstSet;
        while(fs) |ptr| {
            fs = ptr.nextSet;
            ptr.deInit();
        }

        self.allocator.destroy(self);
    }

    pub fn nextResultSet(self: *Self) ?*ResultSet {
        if(self.nextRSet)|ptr| {
           self.nextRSet = ptr.nextSet orelse null;
            return ptr;
        }

        return null;
    } 
};


test " " {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = std.testing.allocator;
    // = gpa.allocator();

    const res = try Result.init(allocator);
    var a = res.nextResultSet();

    try std.testing.expect(a == null);

    const set1 = try ResultSet.init(allocator);
    const set2 = try ResultSet.init(allocator);
    //_ = set2;
    const set3 = try ResultSet.init(allocator);
    //_ = set3;



    res.insert(set1);
    res.insert(set2);
    res.insert(set3);

    a = res.nextResultSet();
    try std.testing.expect(a == set1);

    a = res.nextResultSet();
    try std.testing.expect(set1.nextSet == set2);
    try std.testing.expect(a == set2);

    a = res.nextResultSet();
    try std.testing.expect(set2.nextSet == set3);
    try std.testing.expect(a == set3);

    a = res.nextResultSet();

    try std.testing.expect(a == null);

    const row1 = try Row.init(allocator);
    const row2 = try Row.init(allocator);
    const row3 = try Row.init(allocator);

    const row4 = try Row.init(allocator);
    const row5 = try Row.init(allocator);
    const row6 = try Row.init(allocator);


    const row7 = try Row.init(allocator);
    const row8 = try Row.init(allocator);
    const row9 = try Row.init(allocator);





    set1.insertRow(row1);
    set1.insertRow(row2);
    set1.insertRow(row3);

    set2.insertRow(row4);
    set2.insertRow(row5);
    set2.insertRow(row6);

    set3.insertRow(row7);
    set3.insertRow(row8);
    set3.insertRow(row9);

    var r1 = set1.nextRow();
    try  std.testing.expect(r1 == row1);
    r1 = set1.nextRow();
    try  std.testing.expect(r1 == row2);
    r1 = set1.nextRow();
    try  std.testing.expect(r1 == row3);
    r1 = set1.nextRow();
    try  std.testing.expect(r1 == null);
    r1 = set1.nextRow();
    try  std.testing.expect(r1 == null);

    //try  std.testing.expect(r1 == null);
    //try row1.columns.append("hello");
    //try row1.columns.append("world");
    //try row1.columns.append("bashment");

    //try std.testing.expect(std.mem.eql(u8,row1.columns.getLast(), "bashment")); 

    //try std.testing.expect(row1.columns.capacity == 1);

    res.deinit();


    //const len = res.ResultSets.len;

    //std.debug.print("{}\n", .{len});
}