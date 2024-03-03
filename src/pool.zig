const std = @import("std");
const Threads = std.Thread;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const lib = @import("lib.zig");
const prepStmt = @import("statement.zig").Statement;
const Config = lib.ConnectionConfig;
const c = lib.c;
const Conn = @import("connection.zig").Connection;


pub const ConnectionPool = struct {
    const Self = @This();

    firstConn :*Conn,
    lastConn :*Conn,
    size: usize,
    allocator: Allocator,
    busyConnections: usize,
    poolMutex: Threads.Mutex,
    poolCondition: Threads.Condition,

    pub fn init(allocator :Allocator,config: Config,size :usize) !*Self {
        var checkedSize: usize = 2;
        if(size > checkedSize){
            checkedSize = size;
        }
        const ptmp = try allocator.create(Self);

        ptmp.firstConn = try Conn.newConnection(allocator, config);
        ptmp.firstConn.pooled = true;
        ptmp.lastConn = ptmp.firstConn;
        ptmp.allocator = allocator;

        for(0..checkedSize-1)|_|{
            ptmp.lastConn.next = try Conn.newConnection(allocator, config);
            ptmp.lastConn.next.?.pooled = true;
            ptmp.lastConn = ptmp.lastConn.next.?;
        }

        ptmp.size = checkedSize;
        ptmp.lastConn.next = null;
        ptmp.busyConnections = 0;
        ptmp.poolMutex = Threads.Mutex{};
        ptmp.poolCondition = Threads.Condition{};
        return ptmp;
    }

    pub fn deInit(self :*Self) void {
        
        var ptmp: ?*Conn = self.firstConn;
        for(0..self.size)|_|{
            const conn = ptmp;
            ptmp = ptmp.?.next;
            conn.?.pooled = false;
            conn.?.close();
        }

        self.allocator.destroy(self);
    }

    pub fn getConnection(self: *Self) *Conn {
        self.poolMutex.lock();
        defer self.poolMutex.unlock();
        // wait is all busy
        while(self.busyConnections == self.size){
            self.poolCondition.wait(&(self.poolMutex));
        }

        var currConn: ?*Conn = self.firstConn;
        for(0..self.size)|_|{
            if(currConn.?.idle){
                self.busyConnections += 1;
                currConn.?.idle = false;
                break;
            }

            currConn = currConn.?.next orelse null;
        }

        if(currConn == null){
            unreachable;
        }

        return currConn.?;
    }

    pub fn dropConnection(self: *Self, connection: *Conn) void {
        self.poolMutex.lock();
        defer self.poolMutex.unlock();

        connection.idle = true;
        self.busyConnections -= 1;
        self.poolCondition.signal();
    }

    // pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
    //     const conn = self.getConnection();
    //     defer {
    //         self.dropConnection(conn);
    //     }
    //     const res = try lib.executeQuery(self.allocator,conn.connection, query, parameters);
    //     return res;
    // }

};

test "mem leak" {
     const config: Config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
     const p = try ConnectionPool.init(std.testing.allocator, config, 5);
     p.deInit();
}

const testConfig: Config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
var testPool: *ConnectionPool = undefined;

pub fn testFn() void {
    const id = Threads.getCurrentId();
    std.debug.print("Thread [{}] Aquiring connection \n", .{id});
    const conn = testPool.getConnection();
    std.time.sleep(std.time.ns_per_s);

    std.debug.print("Thread [{}] Dropping connection \n", .{id});
    testPool.dropConnection(conn);
    
}

test "drop" {
    const config: Config = .{ .databaseName = "events", .host = "localhost", .password = "1234Victor", .username = "vic" };
    const p = try ConnectionPool.init(std.testing.allocator, config, 2);

     try expect(p.size == 2);
     const conn1 = p.getConnection();
     _ = conn1;
     const conn2 = p.getConnection();

     try expect(conn2.idle == false);
     try expect(p.busyConnections == 2);

     p.dropConnection(conn2);
     try expect(conn2.idle);
     try expect(p.busyConnections == 1);

     const conn3 = p.getConnection();
     _ = conn3;

     p.deInit();
}

test "all busy" {
    testPool = try ConnectionPool.init(std.testing.allocator, testConfig, 1);
    defer testPool.deInit();

    const t1 = try Threads.spawn(.{}, testFn, .{});
    const t2 = try Threads.spawn(.{}, testFn, .{});
    const t3 = try Threads.spawn(.{}, testFn, .{});

    t2.join();
    t1.join();
    t3.join();
}

test "zero" {
    testPool = try ConnectionPool.init(std.testing.allocator, testConfig, 0);
    defer testPool.deInit();
}
