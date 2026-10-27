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

pub const KeyboardKey = enum {
    a,b,c,d,e,f,g,h,i,j,
    k,l,m,n,o,p,q,r,s,t,
    u,v,w,x,y,z,

    @"0", @"1", @"2", @"3",
    @"4", @"5", @"6", @"7",
    @"8", @"9",

    f1, f2, f3, f4, f5, f6,
    f7, f8, f9, f10, f11, f12,

    space, enter, escape, tab, backspace,
    left, right, up, down,
    lshift, rshift, lctrl, rctrl, lalt, ralt,

    unknown,
};


pub const KeyboardMod = packed struct(u8) {
    shift: bool       = false,
    caps: bool        = false,
    ctrl: bool        = false,
    alternate: bool   = false,
    /// The command key on Mac keyboards and the Windows key on Windows.
    heroKey: bool     = false,
    _padding: u3      = 0, 
};

pub const EventType = enum {
    MouseEvent,
    KeyboardEvent,
    WindowEvent,
};


impl: *anyopaque,
vtable: PlatformVTable,

pub fn createWindow(self: *@This()) void {
    return self.vtable.createWindow(self.impl);
}
