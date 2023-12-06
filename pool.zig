const std = @import("std");
const Threads = std.Thread;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const expect = std.testing.expect;
const Config = @import("connection.zig").ConnectionConfig;
const lib = @import("lib.zig");

const c = @cImport({
    @cInclude("mysql.h");
    @cInclude("stdlib.h");
});


pub const ConnectionPool = struct {
    const Self = @This();

    //connections: ?[*c]c.MYSQL,
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
            threadId: Threads.Id,
            idle: bool,
    };

    pub fn init(allocator :Allocator,config: Config,size :usize) !*Self {

        const ptmp = try allocator.create(Self);

        var firstConnection = try allocator.create(Conn);
        var myqlStructForFirst :?*c.MYSQL = null;
        myqlStructForFirst = c.mysql_init(null);
        try expect(myqlStructForFirst != null);
        myqlStructForFirst = c.mysql_real_connect(myqlStructForFirst, config.host, config.username, config.password, config.databaseName, c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
        try expect(myqlStructForFirst != null);

        firstConnection.connection = myqlStructForFirst.?;
        firstConnection.threadId = @intCast(firstConnection.connection.thread_id);
        firstConnection.idle = true;
        ptmp.firstConn = firstConnection;
        ptmp.lastConn = firstConnection;

        ptmp.allocator = allocator;

        for(0..size-1)|_|{
            print("hello\n",.{});
            var conn :?*c.MYSQL = null;
            conn = c.mysql_init(null);
            try expect(conn != null);
            conn = c.mysql_real_connect(conn, config.host, config.username, config.password, config.databaseName, c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
            try expect(conn != null);

            var newConnecton = try allocator.create(Conn);
            newConnecton.connection = conn.?;
            newConnecton.threadId = @intCast(firstConnection.connection.thread_id);
            newConnecton.idle = true;
            ptmp.lastConn.next = newConnecton;
            ptmp.lastConn = newConnecton;
        }

        ptmp.size = size;
        ptmp.lastConn.next = null;
        ptmp.busyConnections = 0;

        ptmp.poolMutex = Threads.Mutex{};
        ptmp.poolCondition = Threads.Condition{};
    
        return ptmp;
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

        while(self.busyConnections == self.size){
            self.poolCondition.wait(&(self.poolMutex));
        }

        var currConn: ?*Conn = self.firstConn;
        for(0..self.size)|_|{
            if(currConn.?.idle){
                self.busyConnections += 1;
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
    }

    pub fn executeQuery(self: *Self, query: [*c]const u8, parameters: anytype) ![]u8 {
        const conn = self.getConnection();
        defer {
            self.dropConnection(conn);
        }
        const res = try lib.executeQuery(conn.connection, query, parameters);
        return res;
    }

};
