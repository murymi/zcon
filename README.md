
#### Disclaimer: This is just a simple project to learn zig. Even though it works, Use it at your own risk.
works on  zig v0.12.0
#### single connection example
```zig
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const connection = try conn.Connection.newConnection(allocator,.{ 
        .databaseName = "dbname",
         .host = "host",
          .password = "password",
           .username = "username" 
           });

    const res = try connection.executeQuery("select ? as Greeting", .{"hello world"});
    defer allocator.free(res);
    std.debug.print("{s}\n", .{res});

    connection.close();
```

#### pool example

```zig
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const pool = try ConnectionPool.init(allocator,.{ 
        .databaseName = "dbname",
         .host = "host",
          .password = "password",
           .username = "username" 
           },
           4);

    const res = try pool.executeQuery("select ? as Greeting", .{"hello world"});
    defer allocator.free(res);
    std.debug.print("{s}\n", .{res});

    pool.deInit();
```