const bufflist = @import("bufflist.zig");
const connection = @import("connection.zig");
const lib = @import("lib.zig");
const pool = @import("pool.zig");

test "global" {
    _ = bufflist;
    _ = connection;
    _ = lib;
    _ = pool;
}