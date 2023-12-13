const std = @import("std");
const ArrayList = std.ArrayListAligned(u8, null);
const Allocator = std.mem.Allocator;

const Row = struct {
    const Self = @This();

    nextRow: ?*Row,
    columns: ArrayList,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*Self {
        const r = try allocator.create(Self);
        r.* = .{ .nextRow = null, .columns = std.ArrayList(u8).init(allocator), .allocator = allocator };

        return r;
    }

    pub fn deInit(self: *Self) void {
        self.columns.deinit();
        self.allocator.destroy(self);
    }
};

const ResultSet = struct {
    const Self = @This();

    nextSet: ?*Self,
    firstRow: ?*Row,

    allocator: Allocator,

    pub fn init(allocator: Allocator) !*Self {
        const rs = try allocator.create(Self);
        rs.* = .{ .nextSet = null, .firstRow = null,  .allocator = allocator };
        return rs;
    }

    pub fn insertRow(self: *Self, row: *Row) void {
    
        var fr = self.firstRow;

        if(fr) |_| {} else {
            self.firstRow = row;
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
};

const Result = struct {
    const Self = @This();

    resultSets: ?*ResultSet,
    firstSet: ?*ResultSet,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*Self {
        const r = try allocator.create(Self);

        r.* = .{
            .resultSets = null,
            .firstSet = null,
            .allocator = allocator
        };

        return r;
    }

    pub fn insert(self: *Self, set: *ResultSet) void {
        if(self.firstSet) |_|{} else {
            self.firstSet = set;
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
            //self.allocator.destroy(ptr);
            ptr.deInit();
        }

        self.allocator.destroy(self);
    }
};


test " " {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = std.testing.allocator;
    // = gpa.allocator();

    const res = try Result.init(allocator);

    const set1 = try ResultSet.init(allocator);
    const set2 = try ResultSet.init(allocator);
    const set3 = try ResultSet.init(allocator);



    res.insert(set1);
    res.insert(set2);
    res.insert(set3);

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


    res.deinit();


    //const len = res.ResultSets.len;

    //std.debug.print("{}\n", .{len});
}