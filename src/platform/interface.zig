pub const PlatformVTable = struct {
    createWindow: *const fn (*anyopaque) void,
    renameWindow: *const fn (*anyopaque) void,
};

pub const WindowSettingBitmask = packed struct {
    borderless: bool  = true,
    titled: bool      = true,
    closeable: bool   = true,
    minimizable: bool = true,
    resizeable: bool  = true,
    fullscreen: bool  = false,
    ignoreProtectedAreas: bool = false,
};

pub const WindowOptions = struct {
    windowTitle: []const u8 = "Untitled",
    width:       f32 = 600,
    height:      f32 = 600,
    bitmask:     WindowSettingBitmask = .{}
};

impl: *anyopaque,
vtable: PlatformVTable,

pub fn createWindow(self: *@This()) void {
    return self.vtable.createWindow(self.impl);
}
