const std = @import("std");
const Io = std.Io;
const C = @import("C");
const NSApplication = @import("platform/macos/application.zig");
const NSWindow      = @import("platform/macos/window.zig");
const Objc          = @import("platform/macos/objc.zig");

pub fn main(init: std.process.Init) !void {
    var app:    NSApplication = .init(init.gpa, .{});
    const entry = try app.createWindow(.{});
    _ = entry;
    app.run();
}

test "simple test" {
    _ = @import("./platform/macos/objc.zig");
    _ = @import("./platform/macos/application.zig");
    _ = @import("./platform/macos/nsstring.zig");
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
