pub const PlatformVTable = struct {
    createWindow: *const fn (*anyopaque) void,
    renameWindow: *const fn (*anyopaque) void,
};

impl: *anyopaque,
vtable: PlatformVTable,

pub fn createWindow(self: *@This()) void {
    return self.vtable.createWindow(self.impl);
}
