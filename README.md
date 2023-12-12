
#### Disclaimer: This is just a simple project to learn zig. Even though it works, Use it at your own risk.
works on  zig v0.12.0

#### How to compile
```shell
zig run blabla.zig `mysql_config --libs` `mysql_config --cflags` -lc
```
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

    // free result
    defer allocator.free(res);

    std.debug.print("{s}\n", .{res});

    //free pool
    pool.deInit();
```

#### get single connection from pool example

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

    // get it
    const connection = pool.getConnection();

    //drop it
    defer pool.dropConnection(connection);

    //query
    const res = try connection.executeQuery("select ? as Greeting", .{"hello world"});

    // free result
    defer allocator.free(res);

    std.debug.print("{s}\n", .{res});

    //free pool
    pool.deInit();
```

#### single connection prepared statement example
```zig
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const connection = try conn.Connection.newConnection(allocator,.{ 
        .databaseName = "dbname",
         .host = "host",
          .password = "password",
           .username = "username" 
           });

    const stmt = connection.prepare("select ? as Greeting");
    defer stmt.close();

    // execute statement
    var res = try stmt.execute(.{"hello world"});

    // free result
    defer allocator.free(res);

    std.debug.print("{s}\n", .{res});


    // execute statement using another param
    res = try stmt.execute(.{"Good morning"});

    // free result
    defer allocator.free(res);

    std.debug.print("{s}\n", .{res});

    connection.close();
```

#### prepared statement from pool example

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

    const connection = pool.getConnection();
    defer pool.dropConnection(connection);

    //create statement
    const stmt = try connection.prepare("select ? as Greeting");

    //close statement
    defer stmt.close();

    var res = try stmt.execute(.{"hello world"});

    // free result
    defer allocator.free(res);

    std.debug.print("{s}\n", .{res});

    //free pool
    pool.deInit();
```
