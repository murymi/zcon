const std = @import("std");


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
    const libs_to_link = [_][]const u8{"mysqlclient","zstd","ssl", "crypto" ,"resolv" ,"m"};
	
    const module  = b.addModule("zconn", .{
        .root_source_file = std.Build.LazyPath.relative("src/root.zig"),
    });

	const lib = b.addStaticLibrary(.{
		.name = "zconn",
        .root_source_file = .{ .path = "src/root.zig"},
        .optimize = optimize,
        .target = target
	});
	
    lib.linkLibC();
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

    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const short = b.addExecutable(.{
        .target = target,
        .name = "short",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize
    });

    short.linkLibC();
    for(libs_to_link) |l| {
        short.linkSystemLibrary(l);
    }

    //short.root_module.addImport("zconn", module);
    b.installArtifact(short);

    _ = module;

}
