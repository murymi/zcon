const std = @import("std");
const Threads = std.Thread;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const lib = @import("lib.zig");
const prepStmt = @import("statement.zig").Statement;
const Config = lib.ConnectionConfig;
const c = lib.c;


pub const ConnectionPool = struct {
    const Self = @This();

    firstConn :*Conn,
    lastConn :*Conn,
    size: usize,
    allocator: Allocator,
    busyConnections: usize,
    poolMutex: Threads.Mutex,
    poolCondition: Threads.Condition,

    pub const Conn = struct {
            connection: *c.MYSQL,
            next: ?*Conn,
            idle: bool,
            allocator: Allocator,

            pub fn prepare(self: *Conn, query: [*c]const u8) !*prepStmt {
                if(self.idle) return error.connectionIdle;
                return try prepStmt.init(self.allocator,self.connection, query);
            }

            pub fn executeQuery(self: *Conn, query: [*c]const u8, parameters: anytype) ![]u8 {
                return try lib.executeQuery(self.allocator,self.connection, query, parameters);
            }
    };

    pub fn init(allocator :Allocator,config: Config,size :usize) !*Self {
        var checkedSize: usize = 2;
        if(size > checkedSize){
            checkedSize = size;
        }
        const ptmp = try allocator.create(Self);

        ptmp.firstConn = try createConn(allocator, config);
        ptmp.lastConn = ptmp.firstConn;
        ptmp.allocator = allocator;

        for(0..checkedSize-1)|_|{
            ptmp.lastConn.next = try createConn(allocator, config);
            ptmp.lastConn = ptmp.lastConn.next.?;
        }

        ptmp.size = checkedSize;
        ptmp.lastConn.next = null;
        ptmp.busyConnections = 0;
        ptmp.poolMutex = Threads.Mutex{};
        ptmp.poolCondition = Threads.Condition{};
        return ptmp;
    }

    fn createConn(allocator: Allocator, config: Config) !*Conn {
        var newConnecton = try allocator.create(Conn);
        newConnecton.connection = try lib.initConnection(config);
        newConnecton.idle = true;
        newConnecton.allocator = allocator;

        return newConnecton;
    }

    pub fn deInit(self :*Self) void {
        
        var ptmp: ?*Conn = self.firstConn;
        for(0..self.size)|_|{
            c.mysql_close(ptmp.?.connection);
            const conn = ptmp;
            ptmp = ptmp.?.next;
            self.allocator.destroy(conn.?);
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
            //TODO
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

    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
        const conn = self.getConnection();
        defer {
            self.dropConnection(conn);
        }
        const res = try lib.executeQuery(self.allocator,conn.connection, query, parameters);
        return res;
    }

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
