
#### Disclaimer: This is just a simple project to learn zig. Even though it works, Use it at your own risk.
works on  zig v0.12.0

### Example usage 

```shell
$ zig init
```
###### file-> build.zig

```zig

const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const pkg = b.dependency("zconn", .{
        .target = target,
        .optimize = optimize
    });

    const example = pkg.builder.addExecutable(.{
        .target = target,
        .name = "example",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .link_libc = true
    });

    example.root_module.addImport("zconn", pkg.module("zconn"));

    const libs_to_link = [_][]const u8{"mysqlclient","zstd","ssl", "crypto" ,"resolv" ,"m"};

    example.linkLibC();
	
    for(libs_to_link) |l| {
        example.linkSystemLibrary(l);
    }

    b.installArtifact(example);

}

```

###### file-> build.zig.zon

```zig
.{
    .name = "mysql_example",

    .version = "0.0.0",

    .dependencies = .{

        .zconn = .{
            // clone zconn from github
            // replace this with path to clone
            .path = "relative_path_to_clone",
        },
    },

 
    .paths = .{
        "",
    },
}
```

# Examples
#### single connection example
```zig

const std = @import("std");
const sql = @import("zconn");

var gpa = @import("std").heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const allocator = gpa.allocator();
    const conn = try sql.Connection.newConnection(allocator, .{ 
                                                                .username = "vic",
                                                                .databaseName = "events",
                                                                .password = "1234Victor",
                                                                .host = "localhost"
                                                                });


    const res = try conn.executeQuery("select 'hello world' as greeting;", .{});

    if(res.nextResultSet()) |t| {
        if(t.nextRow()) |r| {
            const row = try r.columns.?.toString();
            defer allocator.free(row);

            std.debug.print("{s}\n", .{row});
        } else {
            std.debug.print("Empty set\n", .{});
        }
    } else {
        std.debug.print("Failed to query\n", .{});
    }
 }   
```


#### pool example

```zig

const std = @import("std");
const sql = @import("zconn");

var gpa = @import("std").heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {

    const allocator = gpa.allocator();

    const pool = try sql.Pool.init(allocator,.{ 
        .databaseName = "events",
         .host = "localhost",
          .password = "1234Victor",
           .username = "vic" 
           },
           4);
    defer pool.deInit();

    const conn = pool.getConnection();
    defer pool.dropConnection(conn);

    const res = try conn.executeQuery("select ? as Greeting", .{"hello world"});
    defer res.deinit();

 }   
```

#### get single connection from pool example

```zig

const std = @import("std");
const sql = @import("zconn");

var gpa = @import("std").heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {

    const allocator = gpa.allocator();

    const pool = try sql.Pool.init(allocator,.{ 
        .databaseName = "events",
         .host = "localhost",
          .password = "1234Victor",
           .username = "vic" 
           },
           4);

    defer pool.deInit();

    // get it
    const connection = pool.getConnection();

    //drop it
    defer pool.dropConnection(connection);

    //query
    _ = try connection.executeQuery("select ? as Greeting", .{"hello world"});

 }   
```

#### single connection prepared statement example
```zig

const std = @import("std");
const sql = @import("zconn");

var gpa = @import("std").heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {

    const allocator = gpa.allocator();

    const connection = try sql.Connection.newConnection(allocator,.{ 
        .databaseName = "events",
         .host = "localhost",
          .password = "1234Victor",
           .username = "vic" 
           });

    const stmt = try connection.prepare("select ? as Greeting");
    defer stmt.close();

    // execute statement
    var res1 = try stmt.execute(.{"hello world"});

    // free result 1
    defer res1.deinit();

    //std.debug.print("{s}\n", .{res.});


    // execute statement using another param
    var res2 = try stmt.execute(.{"Good morning"});

    // free result 2
    defer res2.deinit();

    if(res2.nextResultSet()) |re| {
        while(re.nextRow()) |ro| {
            for(0..ro.colCount) |i| {
                std.debug.print("{s}\n", .{ro.columns.?.get(i).?});
            }
        }

    }

    connection.close();
 }   
```

#### prepared statement from pool example

```zig

const std = @import("std");
const sql = @import("zconn");

var gpa = @import("std").heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const allocator = gpa.allocator();

    const pool = try sql.Pool.init(allocator,.{ 
        .databaseName = "events",
         .host = "localhost",
          .password = "1234Victor",
           .username = "vic" 
           },
           4);

    defer pool.deInit();

    const connection = pool.getConnection();
    defer pool.dropConnection(connection);

    //create statement
    const stmt = try connection.prepare("select ? as Greeting");

    //close statement
    defer stmt.close();

    var res = try stmt.execute(.{"hello world"});

    // free result
    defer res.deinit();

    if(res.nextResultSet()) |re| {
        while(re.nextRow()) |ro| {
            const d = try ro.columns.?.toString();
            defer allocator.free(d);
            std.debug.print("{s}\n", .{d});
        }

    }

 }   
```

#### Known bugs
you need to free everything.
