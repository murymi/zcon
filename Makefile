test:
	zig test tests.zig  `mysql_config --libs` `mysql_config --cflags` -lc
