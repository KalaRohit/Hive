// Note that this whole file is AI generated!
// AI BLOCK START
//! Unit test runner for Zig 0.16. Logs are diagnostics, not test results.
//! Use through `zig build test` or `zig test ... --test-runner src/test_runner.zig`.
//! Tests named `benchmark: ...` run only with `zig build test -Dbenchmark=true`.
//! Tests named `integration: ...` run only with `zig build test -Dintegration=true`.
const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

pub const std_options: std.Options = .{ .log_level = .warn };

const Status = enum { pass, skip, fail };

fn hasTestPrefix(name: []const u8, prefix: []const u8) bool {
    // Zig qualifies test names, e.g. "engine.fields.test.benchmark: sphere".
    // Check the start of the declared name, not an arbitrary substring in it.
    const marker = ".test.";
    const declared_name = if (std.mem.indexOf(u8, name, marker)) |index|
        name[index + marker.len..]
    else if (std.mem.startsWith(u8, name, "test."))
        name["test.".len..]
    else
        name;
    return std.mem.startsWith(u8, declared_name, prefix);
}

fn report(index: usize, name: []const u8, status: Status, test_error: ?anyerror, has_leak: bool) void {
    var buffer: [256]u8 = undefined;
    const terminal = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();

    terminal.writer.print("{d}/{d} {s}... ", .{
        index + 1, builtin.test_functions.len, name,
    }) catch return;
    terminal.setColor(switch (status) {
        .pass => .green,
        .skip => .yellow,
        .fail => .red,
    }) catch {};
    terminal.writer.writeAll(switch (status) {
        .pass => "PASS",
        .skip => "SKIP",
        .fail => "FAIL",
    }) catch {};
    terminal.setColor(.reset) catch {};
    if (test_error) |err| terminal.writer.print(" ({s})", .{@errorName(err)}) catch {};
    if (has_leak) terminal.writer.writeAll(" (memory leak)") catch {};
    terminal.writer.writeByte('\n') catch {};
}

fn reportSummary(passed: usize, skipped: usize, failed: usize) void {
    var buffer: [256]u8 = undefined;
    const terminal = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();

    terminal.writer.print("Tests: {d} ran; ", .{builtin.test_functions.len}) catch return;
    terminal.setColor(.green) catch {};
    terminal.writer.print("{d} passed", .{passed}) catch {};
    terminal.setColor(.reset) catch {};
    terminal.writer.writeAll("; ") catch {};
    terminal.setColor(.yellow) catch {};
    terminal.writer.print("{d} skipped", .{skipped}) catch {};
    terminal.setColor(.reset) catch {};
    terminal.writer.writeAll("; ") catch {};
    terminal.setColor(.red) catch {};
    terminal.writer.print("{d} failed", .{failed}) catch {};
    terminal.setColor(.reset) catch {};
    terminal.writer.writeAll(".\n") catch {};
}

pub fn main(init: std.process.Init.Minimal) void {
    // Match `zig test`'s seed argument without allocating from the test allocator.
    var args_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer args_arena.deinit();
    const args = init.args.toSlice(args_arena.allocator()) catch
        @panic("unable to parse test runner arguments");
    var run_benchmarks = false;
    var run_integration = false;
    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--seed=")) {
            testing.random_seed = std.fmt.parseUnsigned(u32, arg["--seed=".len..], 0) catch
                @panic("invalid test runner seed");
        } else if (std.mem.eql(u8, arg, "--benchmark")) {
            run_benchmarks = true;
        } else if (std.mem.eql(u8, arg, "--integration")) {
            run_integration = true;
        } else {
            std.debug.panic("unrecognized test runner argument: {s}", .{arg});
        }
    }

    var passed: usize = 0;
    var skipped: usize = 0;
    var failed: usize = 0;
    var leaked: usize = 0;

    for (builtin.test_functions, 0..) |test_fn, index| {
        if ((!run_benchmarks and hasTestPrefix(test_fn.name, "benchmark:")) or
            (!run_integration and hasTestPrefix(test_fn.name, "integration:")))
        {
            skipped += 1;
            report(index, test_fn.name, .skip, null, false);
            continue;
        }
        testing.allocator_instance = .{};
        testing.environ = init.environ;
        testing.io_instance = .init(testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });
        testing.log_level = .warn;

        var status: Status = .pass;
        var test_error: ?anyerror = null;
        test_fn.func() catch |err| {
            if (err == error.SkipZigTest) {
                status = .skip;
            } else {
                status = .fail;
                test_error = err;
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
            }
        };

        // Tear down I/O before checking the allocator, as I/O can own allocations.
        testing.io_instance.deinit();
        const has_leak = testing.allocator_instance.deinit() == .leak;
        if (has_leak) {
            leaked += 1;
            status = .fail;
        }

        // Each test contributes to exactly one result, including leaking tests.
        switch (status) {
            .pass => passed += 1,
            .skip => skipped += 1,
            .fail => failed += 1,
        }
        // Print the complete result after diagnostics so logs cannot split the line.
        report(index, test_fn.name, status, test_error, has_leak);
    }

    reportSummary(passed, skipped, failed);
    if (leaked != 0) std.debug.print("{d} tests leaked memory.\n", .{leaked});
    if (failed != 0) std.process.exit(1);
}
// AI BLOCK END
