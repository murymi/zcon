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

pub const CustomErr = error {
    sqlErr,
    parameterErr,
    connectionBusy,
    connectionIdle,
    connectionDirty,
};

pub const ConnectionConfig = struct {
    host: [*c]const u8,
    username: [*c]const u8,
    password: [*c]const u8,
    databaseName: [*c]const u8,
};

pub fn executeQuery(allocator: Allocator,mysql: *c.MYSQL, query: [*c]const u8, parameters: anytype) ![]u8 {
    const statement = try prepareStatement(mysql, query);
    defer {
       _= c.mysql_stmt_close(@ptrCast(statement));
    }

    if(fetchResults(allocator,statement,parameters))|res|{
        return res;
    }else |err| {
        switch (err) {
            error.sqlErr => {
                std.debug.panic("{s} - {s}\n", .{ c.mysql_sqlstate(mysql), c.mysql_error(mysql)});
            },
            error.parameterErr =>{
                std.debug.panic("Expected number of parameters not met", .{});
            },
            else =>|e|{
                return e;
            }
        }
    }

    //_= c.mysql_stmt_close(statement);
}

pub fn initConnection(config: ConnectionConfig) CustomErr!*c.MYSQL {
    var conn :?*c.MYSQL = null;
    conn = c.mysql_init(null);
    if(conn) |_| {} else {
        return CustomErr.sqlErr;
    }
    conn = c.mysql_real_connect(conn, config.host, config.username, config.password, config.databaseName, c.MYSQL_PORT, null, c.CLIENT_MULTI_STATEMENTS);
    if(conn) |ptr| {
        return ptr;
    } else {
        return CustomErr.sqlErr;
    }
}

pub fn getColumns(metadata: *c.MYSQL_RES) CustomErr![*c]c.MYSQL_FIELD {
    var colums: ?[*c]c.MYSQL_FIELD = null;
    colums = c.mysql_fetch_fields(metadata);

    if(colums) |ptr| {
        return ptr;
    } else {
        return CustomErr.sqlErr;
    } 
}

pub fn prepareStatement(mysql: *c.MYSQL, query: [*c]const u8) !*c.MYSQL_STMT {
    var statement: ?*c.MYSQL_STMT = null;

    statement = c.mysql_stmt_init(mysql);

    if(statement) |_| {} else {
        return CustomErr.sqlErr;
    } 

    const c_query = @as([*c]u8, @ptrCast(@constCast(@alignCast(query))));
    const err = c.mysql_stmt_prepare(statement, c_query, std.mem.len(c_query));

    if(err != 0){
        return CustomErr.sqlErr;
    }

    return statement.?;
}

pub fn bindParametersToStatement(statement: ?*c.MYSQL_STMT, parameterList: *Bufflist, lengths: *[15]c_ulong) ![*c]c.MYSQL_BIND {

        const param_count = c.mysql_stmt_param_count(statement.?);

        if(param_count != @as(c_ulong, parameterList.size)){
            return error.parameterErr;
        }

        var p_bind: [*c]c.MYSQL_BIND = @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(c.malloc(@sizeOf(c.MYSQL_BIND) *% @as(c_ulong, parameterList.size)))));

        for (0..param_count)|i|{       
            const wcd = try parameterList.getBufferAsString(i);
            lengths.*[i] = @as(c_ulong,wcd.len);
            const bf = @as(?*anyopaque,@ptrCast(@as([*c]u8 ,@ptrCast(@constCast( @alignCast(wcd))))));

            p_bind[i].buffer_type = c.MYSQL_TYPE_STRING;
            p_bind[i].length = &(lengths.*[i]);
            p_bind[i].is_null = 0;
            p_bind[i].buffer = bf;
        }

        const statuss = c.mysql_stmt_bind_param(statement.?, p_bind);

        try std.testing.expect(statuss == false);

        if(statuss){
            return CustomErr.sqlErr;
        }

        if(statement) |_| {} else {
            return CustomErr.sqlErr;
        }

        try executeStatement(statement.?);

        return p_bind;
}

pub fn fillParamsList(alloc: Allocator, config: anytype) !*Bufflist {
    const paramLen = config.len;

    var blistParams: *Bufflist = try Bufflist.init(alloc, paramLen);

    inline for(0..paramLen)|i|{
        const T = @TypeOf(config[i]);

        switch(T){
            i64, i32, i16,i8,i4,bool,comptime_float,comptime_int => |_| {
                var fmtB :[100]u8 = [1]u8{0} ** 100;

                _= try std.fmt.bufPrint(&fmtB, "{}", .{config[i]});
                const ftmpNullStripped = std.mem.sliceTo(&fmtB, 0);

                try blistParams.initAndSetBuffer(ftmpNullStripped, i);
            },

            else => {
                try blistParams.initAndSetBuffer(config[i], i);
            }
        }
    }

    return blistParams;
}

pub fn executeStatement(statement: *c.MYSQL_STMT) CustomErr!void {
    const err = c.mysql_stmt_execute(statement);
    if(std.testing.expect(err == 0))|_|{} else |_|{
        return CustomErr.sqlErr;
    }
}

pub fn getColumnCount(meta: *c.MYSQL_RES) usize {
    const column_count = @as(usize, c.mysql_num_fields(meta));
    return column_count;
}

pub fn getResultMetadata(statement: *c.MYSQL_STMT) !*c.MYSQL_RES {
    var res_meta_data: ?*c.MYSQL_RES = null;
    res_meta_data = c.mysql_stmt_result_metadata(statement);

    if(res_meta_data)|val| {
        return val;
    } else {
       return error.sqlErr;
    }
}

//pub fn getColumnCount()
pub fn bindResultBuffers(allocator: Allocator,statement: *c.MYSQL_STMT, columns: [*c]c.MYSQL_FIELD, columnCount: usize,toBind :*[*c]c.MYSQL_BIND) !*Bufflist {

    //var result_bind: [*c]c.MYSQL_BIND = ;
    toBind.* = @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(c.malloc(@sizeOf(c.MYSQL_BIND) *% @as(c_ulong, columnCount)))));
    const blist = try Bufflist.init(allocator, @as(usize, columnCount));

    for (0..columnCount) |i| {
        toBind.*[i].buffer_type = c.MYSQL_TYPE_STRING;
        const len = @as(usize, (columns.?[i]).length);
        try blist.initBuffer(i, len);
        toBind.*[i].buffer = try blist.getCBuffer(i);
        toBind.*[i].buffer_length = len;
        //toBind.*[i].length = 3000;
    }

    const succ = c.mysql_stmt_bind_result(statement, @as([*c]c.MYSQL_BIND, @ptrCast(@alignCast(toBind.*))));
    if(succ != false){
        return error.sqlErr;
    }

    return blist;
}

pub fn getAffectedRows(allocator: Allocator, statement: *c.MYSQL_STMT) ![]u8 {

    var list: ArrayList(u8) = ArrayList(u8).init(allocator);
    defer list.deinit();

    var wr = writeStream(list.writer(), .{ .whitespace = .indent_1 });
    defer wr.deinit();

    try wr.beginObject();
    try wr.objectField("Affected rows");
    const affectedRows = c.mysql_stmt_affected_rows(statement);
    try wr.write(affectedRows);
    try wr.endObject();

    return try allocator.dupe(u8, list.items);
}

pub fn fetchResults(allocator: Allocator,statement: *c.MYSQL_STMT,parameters: anytype) ![]u8 {
    var pbuff: ?*Bufflist = null;
    var binded: ?[*c]c.MYSQL_BIND = null;

    var lengths: [15]c_ulong = [1]c_ulong{0} ** 15;

    defer {
        if(binded)|ptr|{
            c.free(@as(?*anyopaque,@ptrCast(ptr)));
        }

        if(pbuff)|ptr|{
            ptr.deInit();
        }
    }

    switch(parameters.len > 0){
        true => { 
            pbuff = try fillParamsList(allocator,parameters);

            binded = try bindParametersToStatement(statement, pbuff.?,&lengths);
        },
        else => {
           try executeStatement(statement);
        }
    }

    var metadata: *c.MYSQL_RES = undefined;
    defer {
        if(metadata != undefined){
            _ = c.mysql_free_result(metadata);
        }
    }

    if(getResultMetadata(statement)) |val| {
        metadata = val;
    } else |_|{
        return try getAffectedRows(allocator, statement);
    }

    const columnCount = getColumnCount(metadata);
    const columns = try getColumns(metadata);

    var resBind: [*c]c.MYSQL_BIND = undefined;
    const resultBuffers = try bindResultBuffers(allocator,statement, columns, 
    columnCount, &resBind);
    defer resultBuffers.deInit();
    var list = ArrayList(u8).init(allocator);
    defer list.deinit();

    var wr = writeStream(list.writer(), .{ .whitespace = .indent_1 });
    defer wr.deinit();
    try wr.beginArray();

    while (c.mysql_stmt_fetch(statement) == @as(c_int, 0)) {
        try wr.beginObject();
        for (0..columnCount) |v| {
            const czstr = try cStringToZigString((columns.?[v]).name, allocator);
            defer allocator.free(czstr);
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
                    try wr.write(value);
                },
            }
        }
        try wr.endObject();
    }

    try wr.endArray();

    //ToDo
    while (c.mysql_stmt_next_result(statement) == @as(c_int, 0)) {}

    return try allocator.dupe(u8, list.items);
}

pub fn cStringToZigString(cString: [*]const u8, allocator: Allocator) ![]const u8 {
    var index: usize = 0;
    while (cString[index] != 0) : (index += 1) {}

    const zigString = try allocator.dupe(u8, cString[0..index]);
    return zigString;
}

test "fill " {
    const alloc = std.testing.allocator;
    const a = try fillParamsList(alloc,.{"hello", "world"});
    try expect(a.size == 2);
    a.deInit();
}
