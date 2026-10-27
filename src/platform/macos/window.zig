//! Wrapper around NSWindow for easy zig interop.
const std              = @import("std");
const builtin          = @import("builtin");
const Interface        = @import("../interface.zig");
const Objc             = @import("objc.zig");
const NSString         = @import("nsstring.zig");

pub const MacOsWindow = @This();

allocator: std.mem.Allocator,
handle: *anyopaque,

height: f32        = 600,
width: f32         = 600,
title: NSString,

const MacosWindowOption = extern struct {
    x:      f64,
    y:      f64,
    width:  f64,
    height: f64
};

/// Refer to: https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct
const MacosWindowStyleMask = packed struct {
    borderless: bool  = true,
    titled: bool      = true,
    closeable: bool   = true,
    minimizable: bool = true, // Macos refers to this as miniaturizable,
    resizeable: bool  = true,
    unifiedTitleAndToolbar: bool = true, // Note: useless,
    fullscreen: bool = false,
    fullscreenContentView: bool = false, // This ignores the reserved toolbar area.
    utilityWindow: bool  = false,
    docModalWindow: bool = false,
    nonActivatingPanel: bool = false,
    HUDWindow: bool = false
};

pub fn init(
    allocator: std.mem.Allocator,
    options: Interface.WindowOptions
) !MacOsWindow {
    std.debug.assert(options.width  < 10_000);
    std.debug.assert(options.height < 10_000);

    const title: NSString = try NSString.fromUTF8(options.windowTitle);
    errdefer title.deinit();

    const internalWindowOption = MacosWindowOption{
        .x      = 0,
        .y      = 0,
        .height = options.height,
        .width  = options.width,
    };
    const styleMask: MacosWindowStyleMask = .{
        .borderless  = options.bitmask.borderless,
        .fullscreen  = options.bitmask.fullscreen,
        .closeable   = options.bitmask.closeable,
        .minimizable = options.bitmask.minimizable,
        .resizeable  = options.bitmask.resizeable,
        .titled      = options.bitmask.titled,
    }; // TODO:: Need to find a way for setting the rest of the flags
    const windowAllocRef = Objc.dynamicDispatch(
        *anyopaque,
        Objc.getClass(@tagName(Objc.ClassName.NSWindow)),
        Objc.getSelector("alloc"),
        .{}
    );
    const buffered: c_int = 0;
    const mask: usize = @as(u12, @bitCast(styleMask));

    const windowHandle = Objc.dynamicDispatch(
        *anyopaque,
        windowAllocRef,
        Objc.getSelector("initWithContentRect:styleMask:backing:defer:"),
        .{
            internalWindowOption,
            @as(usize, @intCast(mask)),
            buffered,
            false
        }
    );
    Objc.dynamicDispatch(
        void,
        windowHandle,
        Objc.getSelector("setTitle:"),
        .{
            title.getHandle()
        }
    );

    Objc.dynamicDispatch(
        void,
        windowHandle,
        Objc.getSelector("makeKeyAndOrderFront:"), .{
            Objc.NULL,
        }
    );

    return MacOsWindow {
        .allocator = allocator,
        .handle    = windowHandle,
        .height    = options.height,
        .width     = options.width,
        .title     = title
    };
}

pub fn close(self: *const MacOsWindow) void {
    Objc.dynamicDispatch(
        void, 
        self.handle, 
        Objc.getSelector("close"), 
        .{}
    );
}

pub fn deinit(self: *MacOsWindow) void {
    self.close();
    self.title.deinit();
}
