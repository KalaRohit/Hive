//! Integrate with Apple's Objective C runtime using these Zig functions.
//! Only adding functions on a need by need basis, so the full set is not
//! implemented.
//! Documentation of these functions can be found here: https://developer.apple.com/documentation/objectivec/
const c       = @import("C");
const std     = @import("std");
const builtin = @import("builtin");

/// Returns the class definition of a specified class.
pub fn getClass(className: [:0]const u8) ?*anyopaque {
    return c.objc_getClass(
        className.ptr
    );
}

test "Objective C Runtime: ensure we can find classes used in the application" {
    if (builtin.os.tag != .macos) return error.SkipZigTest;

    try std.testing.expect(
        getClass("NSApplication") != null
    );
    try std.testing.expect(
        getClass("NSWindow") != null
    );
    try std.testing.expect(
        getClass("NSEvent") != null
    );
}

/// Registers a method name with the Objective-C runtime system.
///
/// The unique id is a method name, for example: "sharedApplication".
///
/// The actual function is called: sel_getUid.
///
/// Read more here: https://developer.apple.com/documentation/objectivec/sel_getuid(_:)
pub fn getMethodSelectorForUniqueId(methodName: [:0]const u8) ?*anyopaque {
    return c.sel_getUid(
        methodName
    );
}

test "Objective C Runtime: ensure we can select methods from classes" {
    if (builtin.os.tag != .macos) return error.SkipZigTest;

    try std.testing.expect(
        getMethodSelectorForUniqueId("sharedApplication") != null
    );
}

/// Sends a message with a simple return value to an instance of a class.
///
/// The underlying method is called objc_msgSend with docs here: https://developer.apple.com/documentation/objectivec/objc_msgsend
///
/// This method does a dynamic dispatch of an objective C function by:
/// Find method for (self) with name (op) and calls
/// `self.op(args...)`.
///
/// You can specify the return type with comptime Return. They are usually raw ptrs.
pub fn dynamicDispatch(
    comptime Return: type,
    self: ?*anyopaque,
    op:   ?*anyopaque,
    args: anytype,
) Return {
    const info = @typeInfo(@TypeOf(args)).@"struct";

    if (!info.is_tuple) @compileError("args must be a tuple...");

    // Type information is generated at compile time since
    // objective-c does not interop well with variadic args...
    const functionParameterTypes = comptime blk: {
        var types: [2 + info.fields.len]type = undefined;

        types[0] = ?*anyopaque;
        types[1] = ?*anyopaque;

        for (info.fields, 2..) |T, i| {
            types[i] = T.type;
        }

        break :blk types;
    };

    const Fn = @Fn(
        &functionParameterTypes,
        &@splat(.{}),
        Return, .{
            .@"callconv" = .c
        }
    );

    const clsMsgSend: *const Fn = @ptrCast(&c.objc_msgSend);
    return @call(.auto, clsMsgSend, .{self, op} ++ args);
}

test "Objective C Runtime: example creating an application using raw objective c methods" {
    if (builtin.os.tag != .macos) return error.SkipZigTest;

    const NsActivationPolicyRegular: c_int = 0;

    const appClassRef     = getClass("NSApplication");
    const methodRef       = getMethodSelectorForUniqueId("sharedApplication");
    const app: *anyopaque = dynamicDispatch(*anyopaque, appClassRef, methodRef, .{});
    dynamicDispatch(
        void,
        app,
        getMethodSelectorForUniqueId("setActivationPolicy:"), .{NsActivationPolicyRegular}
    );
    const windowAlloc   = dynamicDispatch(
        *anyopaque,
        getClass("NSWindow"),
        getMethodSelectorForUniqueId("alloc"),
        .{}
    );
    const WindowOpts = extern struct {
        x: c_longdouble,
        y: c_longdouble,
        width: c_longdouble,
        height: c_longdouble
    };
    const frameRect = WindowOpts{
        .x = 0,
        .y = 0,
        .height = 600,
        .width = 600
    };
    const window = dynamicDispatch(
        *anyopaque,
        windowAlloc,
        getMethodSelectorForUniqueId("initWithContentRect:styleMask:backing:defer:"), .{
            frameRect,
            @as(c_int, @intCast(0)),
            @as(c_int, @intCast(0)),
            false
        }
    );
    _ = window;
}
