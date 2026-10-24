//! Lightweight construction around NSString.
//! We let obj-c keep the memory and allocation,
//! and simply read into it when we need it on the zig side.

const Objc = @import("objc.zig");
const std = @import("std");
const builtin = @import("builtin");

const NSString = @This();

handle: *anyopaque,

const utf8_encoding: usize = 4; // NSUTF8StringEncoding

pub fn fromUTF8(bytes: []const u8) !NSString {
    const cls = Objc.getClass("NSString")
        orelse return error.ClassNotFound;

    const allocated = Objc.dynamicDispatch(
        ?*anyopaque,
        cls,
        Objc.getMethodSelectorForUniqueId("alloc"),
        .{},
    ) orelse return error.OutOfMemory;

    const initialized = Objc.dynamicDispatch(
        ?*anyopaque,
        allocated,
        Objc.getMethodSelectorForUniqueId(
            "initWithBytes:length:encoding:"
        ),
        .{ bytes.ptr, bytes.len, utf8_encoding },
    ) orelse return error.InvalidUTF8;

    return .{
        .handle = initialized,
    };
}

pub fn getHandle(self: *const NSString) *anyopaque {
    return self.handle;
}

pub fn getZigString(self: *const NSString) []const u8 {
    const ptr = Objc.dynamicDispatch(
        [*:0]const u8,
        self.handle,
        Objc.getMethodSelectorForUniqueId("UTF8String"),
        .{},
    );

    return std.mem.span(ptr);
}

pub fn deinit(self: *NSString) void {
    Objc.dynamicDispatch(
        void,
        self.handle,
        Objc.getMethodSelectorForUniqueId("release"),
        .{},
    );

    self.* = undefined;
}


test "NSString implementation and usage" {
    if (builtin.os.tag != .macos) return error.SkipZigTest;
    const string: NSString = try .fromUTF8("ExampleString");
    try std.testing.expect(std.mem.eql(u8, string.getZigString(), "ExampleString"));
}
