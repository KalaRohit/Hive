//! Wrapper around NSApplication and Objc to interact with
//! Apple's NSApplication interfaces.

const std     = @import("std");
const Objc    = @import("objc.zig");
const builtin = @import("builtin");
const Window  = @import("window.zig");
const Interface = @import("../interface.zig");

pub const MacOSApplication = @This();

/// **Regular**:    An ordinary application which can be clicked on in the dock, and may have a UI.
///
/// **Accessory**:  Application will NOT appear in the dock, won't have a menu bar but can be activated via programs or by clicking on a window it has.
///
/// **Prohibited**: Won't appear in the dock, cannot be activated or create windows.
///
/// For more documentation, refer to: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum
pub const MacOsActivationPolicy = enum(c_uint) {
    Regular    = 0,
    Accessory  = 1,
    Prohibited = 2
};

pub const WindowEntry = struct {
    window:     Window,
    generation: usize,
    index     : usize
};

pub const MacOsApplicationOptions = struct {
    activationPolicy: MacOsActivationPolicy = .Regular,
    title: []const u8 = "Untitled",
};

app_handle: *anyopaque,
gpa: std.mem.Allocator,
running: bool                       = true,
activationPolicy: MacOsActivationPolicy,
windows: std.ArrayList(WindowEntry) = .empty,
freeSlots: std.ArrayList(usize)     = .empty,

pub fn init(allocator: std.mem.Allocator, options: MacOsApplicationOptions) MacOSApplication {
    const appClassRef     = Objc.getClass(@tagName(Objc.ClassName.NSApplication));
    const methodRef       = Objc.getMethodSelectorForUniqueId("sharedApplication");
    const app: *anyopaque = Objc.dynamicDispatch(*anyopaque, appClassRef, methodRef, .{});
    Objc.dynamicDispatch(
        void,
        app,
        Objc.getMethodSelectorForUniqueId("setActivationPolicy:"),
        .{
            @intFromEnum(options.activationPolicy)
        }
    );
    Objc.dynamicDispatch(void, app, Objc.getMethodSelectorForUniqueId("activateIgnoringOtherApps:"), .{ true });

    return MacOSApplication{
        .app_handle       = app,
        .gpa              = allocator,
        .activationPolicy = options.activationPolicy
    };
}

/// Create a window, free a previously closed window if needed to make room.
pub fn createWindow(
    self: *MacOSApplication,
    options: Interface.WindowOptions
) !WindowEntry {
    const freeSlot: ?usize = self.freeSlots.pop();
    const windowHandle = try Window.init(self.gpa, options);
    var windowEntry: WindowEntry = undefined;

    if (freeSlot) |validSlot| {
        var prevEntry: WindowEntry = self.windows.items[validSlot];
        prevEntry.window.deinit();
        const newGen = prevEntry.generation + 1;

        self.windows.items[validSlot] = WindowEntry{
            .window     = windowHandle,
            .generation = newGen,
            .index      = validSlot
        };
        windowEntry = self.windows.items[validSlot];
    } else {
        try self.windows.append(self.gpa, WindowEntry{
            .window     = windowHandle,
            .generation = 0,
            .index      = self.windows.items.len
        });
        windowEntry = self.windows.items[self.windows.items.len - 1];
    }

    return windowEntry;
}

/// Note that freeing of the resources happens at a much later time.
/// This simply marks the resource to be overriden at a later period.
pub fn markWindowForRemoval(
    self: *MacOSApplication,
    entry: WindowEntry
) !void {
    if (self.windows.items[entry.index].generation != entry.generation) return;
    try self.freeSlots.append(self.gpa, entry.index);
    entry.window.close();
}

test "MacOS Application: add and remove windows" {

}

pub fn run(self: *const @This()) void {
    Objc.dynamicDispatch(void, self.app_handle, Objc.getMethodSelectorForUniqueId("run"), .{});
}

pub fn deinit(self: *const MacOSApplication) void {
    const terminateRef = Objc.getMethodSelectorForUniqueId("terminate:");
    Objc.dynamicDispatch(void, self.app_handle, terminateRef, .{});
}

test "MacOs Application: init and deinit" {
    const allocator: std.mem.Allocator = std.testing.allocator;
    // var threaded = std.Io.Threaded.init(allocator, .{});
    // const io = threaded.io();

    const app: MacOSApplication = .init(allocator, .{});
    _ = app;
    // defer app.deinit();
}
