const std = @import("std");
const os = std.os;
const Bufflist = @import("bufflist.zig").BuffList;
const ArrayList = std.ArrayList;
const json = std.json;
const writeStream = json.writeStream;
const Allocator = std.mem.Allocator;
const time = std.time;
const expect = std.testing.expect;

pub const c = @cImport({
    @cInclude("mysql.h");
    @cInclude("stdlib.h");
});

pub const ConnectionConfig = struct {
    host: [*c]const u8,
    username: [*c]const u8,
    password: [*c]const u8,
    databaseName: [*c]const u8,
};

pub fn executeQuery(mysql: *c.MYSQL, query: [*c]const u8, parameters: anytype) ![]u8 {
    _ = parameters;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stmt = try prepareStatement(mysql, query);
    try executeStatement(stmt);
    const metadata = try getResultMetadata(stmt);
    const columnCount = getColumnCount(metadata);
    const columns = try getColumns(metadata);
    const resultBuffers = try bindResultBuffers(allocator,stmt, columns, columnCount);
    const res = try fetchResults(allocator,stmt, columns, columnCount, resultBuffers);
    //resultBuffers.
    return res;
}

pub fn initConnection(config: ConnectionConfig) !*c.MYSQL {
    var conn :?*c.MYSQL = null;
    conn = c.mysql_init(null);
    try expect(conn != null);
    conn = c.mysql_real_connect(conn, config.host, config.username, config.password, config.databaseName, c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
    try expect(conn != null);
    return conn.?;
}

pub fn getColumns(metadata: *c.MYSQL_RES) ![*c]c.MYSQL_FIELD {
    var colums: ?[*c]c.MYSQL_FIELD = null;
    colums = c.mysql_fetch_fields(metadata);
    try std.testing.expect(colums != null);

    return colums.?;
}

pub fn prepareStatement(mysql: *c.MYSQL, query: [*c]const u8) !*c.MYSQL_STMT {
    var statement: ?*c.MYSQL_STMT = null;

    statement = c.mysql_stmt_init(mysql);

    try std.testing.expect(statement != null);

    const c_query = @as([*c]u8, @ptrCast(@constCast(@alignCast(query))));

    std.debug.print("query is {s}\n", .{c_query});

    const err = c.mysql_stmt_prepare(statement, c_query, std.mem.len(c_query));

    try std.testing.expect(err == 0);

    return statement.?;
}

//pub fn execute

pub fn bindParametersToStatement(statement: *c.MYSQL_STMT, parameterList: Bufflist) void {
    const param_count = c.mysql_stmt_param_count(statement);

    //try std.testing.expect(param_count == @as(c_ulong, paramLen));

    var p_bind: [*c]c.MYSQL_BIND = @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(c.malloc(@sizeOf(c.MYSQL_BIND) *% @as(c_ulong, param_count)))));

    for (0..param_count) |i| {
        //len[i] = strlen(result_bind_get_string(i, params));
        const wcd = try parameterList.getBufferAsString(i);
        var ll: c_ulong = wcd.len;
        const bf = @as(?*anyopaque, @ptrCast(@as([*c]u8, @ptrCast(@constCast(@alignCast(wcd))))));

        //const bufflen :c_ulong = bf.len;

        p_bind[i].buffer_type = c.MYSQL_TYPE_LONG;
        //result_bind_get_at(i, params)->type_name;
        p_bind[i].is_null = 0;
        p_bind[i].length = &(ll);

        //char *b_str = result_bind_get_string(i, params);
        p_bind[i].buffer = bf;
        p_bind[i].buffer_length = 3;
        //strlen(b_str);

    }

    const statuss = c.mysql_stmt_bind_param(statement, p_bind);

    try std.testing.expect(statuss == false);

    try std.testing.expect(statement != null);

    return p_bind;
}

pub fn fillParamsList(config: anytype) !Bufflist {
    const paramLen = config.len;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var blistParams: *Bufflist = try Bufflist.init(alloc, paramLen);

    inline for (0..paramLen) |i| {
        const T = @TypeOf(config[i]);

        switch (T) {
            i64, i32, i16, i8, i4, bool, comptime_float, comptime_int => |_| {
                var fmtB: [100]u8 = [1]u8{0} ** 100;
                _ = try std.fmt.bufPrint(&fmtB, "{}", .{config[i]});
                const ftmpNullStripped = std.mem.sliceTo(&fmtB, 0);

                try blistParams.initAndSetBuffer(ftmpNullStripped, i);
            },

            else => {
                try blistParams.initAndSetBuffer(config[i], i);
            },
        }
    }

    return blistParams;
}

pub fn executeStatement(statement: *c.MYSQL_STMT) !void {
    const err = c.mysql_stmt_execute(statement);
    try std.testing.expect(err == 0);
}

pub fn getColumnCount(meta: *c.MYSQL_RES) usize {
    const column_count = @as(usize, c.mysql_num_fields(meta));
    return column_count;
}

pub fn getResultMetadata(statement: *c.MYSQL_STMT) !*c.MYSQL_RES {
    var res_meta_data: ?*c.MYSQL_RES = null;
    res_meta_data = c.mysql_stmt_result_metadata(statement);
    try std.testing.expect(res_meta_data != null);
    return res_meta_data.?;
}

//pub fn getColumnCount()
pub fn bindResultBuffers(allocator: Allocator,statement: *c.MYSQL_STMT, columns: [*c]c.MYSQL_FIELD, columnCount: usize) !*Bufflist {
    var result_bind: [*c]c.MYSQL_BIND = @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(c.malloc(@sizeOf(c.MYSQL_BIND) *% @as(c_ulong, columnCount)))));
    const blist = try Bufflist.init(allocator, @as(usize, columnCount));

    for (0..columnCount) |i| {
        result_bind[i].buffer_type = c.MYSQL_TYPE_STRING;

        const len = @as(usize, (columns.?[i]).length);
        try blist.initBuffer(i, len);

        //std.debug.print("Length {}\n", .{len});
        result_bind[i].buffer = blist.getCBuffer(i);
        result_bind[i].buffer_length = len;
    }

    const succ = c.mysql_stmt_bind_result(statement, @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(result_bind))));
    try std.testing.expect(succ == false);

    return blist;
}

pub fn fetchResults(allocator: Allocator,statement: *c.MYSQL_STMT, columns: [*c]c.MYSQL_FIELD, columnCount: usize, resultBuffers: *Bufflist) ![]u8 {
    var list = ArrayList(u8).init(allocator);

    var wr = writeStream(list.writer(), .{ .whitespace = .indent_1 });
    try wr.beginArray();

    while (c.mysql_stmt_fetch(statement) == @as(c_int, 0)) {
        try wr.beginObject();
        for (0..columnCount) |v| {
            const czstr = try cStringToZigString((columns.?[v]).name, allocator);
            try wr.objectField(czstr);
            const value = try resultBuffers.getBufferAsString(v);
            const dataType = (columns.?[v]).type;

            switch (dataType) {
                c.MYSQL_TYPE_SHORT => try wr.write(try std.fmt.parseInt(i16, value, 10)),
                c.MYSQL_TYPE_BOOL => {
                    try wr.write(switch (try std.fmt.parseInt(i8, value, 10)) {
                        0 => false,
                        else => true,
                    });
                },
                c.MYSQL_TYPE_LONGLONG => try wr.write(try std.fmt.parseInt(i64, value, 10)),
                c.MYSQL_TYPE_BIT => try wr.write(try std.fmt.parseInt(i1, value, 10)),
                c.MYSQL_TYPE_LONG => try wr.write(try std.fmt.parseInt(i32, value, 10)),
                c.MYSQL_TYPE_NULL => try wr.write(null),
                c.MYSQL_TYPE_TINY => try wr.write(try std.fmt.parseInt(i8, value, 10)),
                c.MYSQL_TYPE_DECIMAL, c.MYSQL_TYPE_DOUBLE, c.MYSQL_TYPE_FLOAT, c.MYSQL_TYPE_NEWDECIMAL => try wr.write(try std.fmt.parseFloat(f64, value)),
                else => {
                    //std.debug.print("===={} {s}====\n", .{dataType, value});
                    try wr.write(value);
                },
            }

            //std.debug.print("{s}\n",.{blist.getBuffer(v).*});

            //std.debug.print("type is {}\n", .{(colums.? + v).*.@"type"});
        }
        try wr.endObject();
    }

    //std.mem.sp

    try wr.endArray();

    //todo
    while (c.mysql_stmt_next_result(statement) == @as(c_int, 0)) {}

    const resultsJson = std.mem.sliceTo(list.items, 0);
    return resultsJson;
}

pub fn cStringToZigString(cString: [*]const u8, allocator: Allocator) ![]const u8 {
    var index: usize = 0;
    while (cString[index] != 0) : (index += 1) {}

    const zigString = try allocator.dupe(u8, cString[0..index]);
    return zigString;
}
