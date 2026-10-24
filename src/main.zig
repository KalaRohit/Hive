const std = @import("std");
const Io = std.Io;
const C = @import("C");

pub fn main(init: std.process.Init) !void {
    const cls_msg = @as(*const fn (?*anyopaque, ?*anyopaque, ...) callconv(.c) ?*anyopaque, @ptrCast(&C.objc_msgSend));

    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    _ = cls_msg(C.objc_getClass("NSApplication"), C.sel_registerName("sharedApplication"));
    while (true) {}
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    _ = @import("./platform/macos/objc.zig");
}

// Keeping the fuzzing example here for now so i can review it later.
// test "fuzz example" {
//     try std.testing.fuzz({}, testOne, .{});
// }
//
// fn testOne(context: void, smith: *std.testing.Smith) !void {
//     _ = context;
//     // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//
//     const gpa = std.testing.allocator;
//     var list: std.ArrayList(u8) = .empty;
//     defer list.deinit(gpa);
//     while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
//         .add_data => {
//             const slice = try list.addManyAsSlice(gpa, smith.value(u4));
//             smith.bytes(slice);
//         },
//         .dup_data => {
//             if (list.items.len == 0) continue;
//             if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
//             const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
//             const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
//             try list.appendSlice(gpa, list.items[off..][0..len]);
//             try std.testing.expectEqualSlices(
//                 u8,
//                 list.items[off..][0..len],
//                 list.items[list.items.len - len ..],
//             );
//         },
//     };
// }
