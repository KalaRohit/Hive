const std = @import("std");

/// Setup the build properly
pub fn prePass(
    b:  *std.Build,
    io: std.Io,
) void {
    _ = b;
    const git_args: []const []const u8 = &.{
        "git",
        "submodule",
        "update",
        "--init",
        "--recursive"
    };
    var clone_deps = std.process.spawn(
        io,
        .{
            .argv = git_args
        }
    ) catch {
        std.log.err("Failed to clone submodules", .{});
        @panic("Build failed");
    };

    const sig_term = clone_deps.wait(io) catch @panic("Build failed");
    switch (sig_term) {
        .exited => |code| {
            if (code != 0) {
                @panic("Build failed");
            }
        },
        else   => {
            @panic("Build failed");
        }
    }
}

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    var threaded = std.Io.Threaded.init(
        std.heap.page_allocator, .{}
    );
    const io = threaded.io();
    prePass(b, io);
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = b.addTranslateC(.{
        .optimize = optimize,
        .target   = target,
        .root_source_file = b.path("include.h"),
        .link_libc = true
    });
    t.linkSystemLibrary("vulkan", .{});
    const exe = b.addExecutable(.{
        .name = "Hive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addImport("C", t.createModule());
    // maconly
    exe.root_module.linkFramework("Cocoa", .{});
    exe.root_module.linkSystemLibrary("objc", .{});
    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
        .test_runner = .{
            .path = b.path("src/test_runner.zig"),
            .mode = .simple
        },
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
