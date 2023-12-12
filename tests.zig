const bufflist = @import("src/bufflist.zig");
const connection = @import("src/connection.zig");
const lib = @import("src/lib.zig");
const pool = @import("src/pool.zig");

test "global" {
    _ = bufflist;
    _ = connection;
    _ = lib;
    _ = pool;
}