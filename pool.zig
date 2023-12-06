const std = @import("std");
const Threads = std.Thread;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const expect = std.testing.expect;
const Config = @import("connection.zig").ConnectionConfig;

const c = @cImport({
    @cInclude("mysql.h");
    @cInclude("stdlib.h");
});


const ConnectionPool = struct {
    const Self = @This();

    //connections: ?[*c]c.MYSQL,
    firstConn :*Conn,
    lastConn :*Conn,
    size: usize,
    allocator: Allocator,
    busyConnections: usize,

    pub const Conn = struct {
            connection: *c.MYSQL,
            next: ?*Conn,
            threadId: Threads.Id,
    };

    pub fn init(allocator :Allocator,size :usize) !*Self {

        const ptmp = try allocator.create(Self);

        var firstConnection = try allocator.create(Conn);
        var myqlStructForFirst :?*c.MYSQL = null;
        myqlStructForFirst = c.mysql_init(null);
        try expect(myqlStructForFirst != null);
        myqlStructForFirst = c.mysql_real_connect(myqlStructForFirst, "localhost", "vic", "1234Victor", "events", c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
        try expect(myqlStructForFirst != null);

        firstConnection.connection = myqlStructForFirst.?;
        firstConnection.threadId = @intCast(firstConnection.connection.thread_id);
        ptmp.firstConn = firstConnection;
        ptmp.lastConn = firstConnection;

        //const conns = @as(?[*c]c.MYSQL, @ptrCast(@alignCast(c.malloc(@sizeOf(c.MYSQL) *% @as(c_ulong, @bitCast(size))))));
        //@memset(conns.?, null);

        //ptmp.connections = conns;
        //ptmp.size = size;
        ptmp.allocator = allocator;



        for(0..size-1)|_|{
            print("hello\n",.{});
            var conn :?*c.MYSQL = null;
            conn = c.mysql_init(null);
            try expect(conn != null);
            conn = c.mysql_real_connect(conn, "localhost", "vic", "1234Victor", "events", c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
            try expect(conn != null);

            var newConnecton = try allocator.create(Conn);
            newConnecton.connection = conn.?;
            newConnecton.threadId = @intCast(firstConnection.connection.thread_id);
            ptmp.lastConn.next = newConnecton;
            ptmp.lastConn = newConnecton;
        }

        ptmp.size = size;
        ptmp.lastConn.next = null;
        ptmp.busyConnections = 0;
    
        return ptmp;
    }

    pub fn deInit(self :*Self) void {
        
        var ptmp: ?*Conn = self.firstConn;
        for(0..self.size)|_|{
            //c.mysql_close(@as([*c]c.MYSQL,@ptrCast(self.connections.?[i])));

            c.mysql_close(ptmp.?.connection);
            const conn = ptmp;
            ptmp = ptmp.?.next;
            self.allocator.destroy(conn.?);
        }

        self.allocator.destroy(self);
    }
    //@as(?[*c]c.MYSQL, @ptrCast(@alignCast(std.heap.c_allocator.alloc(c.MYSQL, size))));
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const pl = try ConnectionPool.init(alloc, 4);

    try expect(pl.size == 4);

    pl.deInit();

    //try expect(pl.size == 4);
}