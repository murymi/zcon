const std = @import("std");


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
    const libs_to_link = [_][]const u8{"mysqlclient","zstd","ssl", "crypto" ,"resolv" ,"m"};
	
    _ = b.addModule("zconn", .{
        .source_file = .{ .path = "src/root.zig"}
    });

	const lib = b.addStaticLibrary(.{
		.name = "zconn",
        .root_source_file = .{ .path = "src/root.zig"},
        .optimize = optimize,
        .target = target
	});
	
    for(libs_to_link) |l| {
        lib.linkSystemLibrary(l);
    }

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .optimize = optimize,
        .link_libc = true,
    });


    for(libs_to_link) |l| {
        main_tests.linkSystemLibrary(l);
    }

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

}
