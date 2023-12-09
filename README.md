#### single connection example
```
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

```
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