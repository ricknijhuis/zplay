const builtin = @import("builtin");
const core = @import("core");

const context = @import("context.zig");
const Win32Window = @import("Win32Window.zig");
const Window = @import("Window.zig");
const HandleSet = core.HandleSet;
const Handle = HandleSet(Window).Handle;

const WindowHandle = @This();

const instance = &context.instance;

pub const ModeType = enum {
    windowed,
    borderless,
    fullscreen,
};

pub const ModeState = enum {
    normal,
    minimized,
    maximized,
    hidden,
};

pub const Mode = union(ModeType) {
    windowed: ModeState,
    borderless: ModeState,
    fullscreen,
};

pub const InitParams = struct {
    mode: Mode,
    title: []const u8,
    width: u32,
    height: u32,
};

handle: Handle = .none,

pub fn init(params: InitParams) !WindowHandle {
    core.asserts.isOnThread(instance.main_thread);

    const gpa = instance.gpa;
    const handle = try instance.windows.addOneExact(gpa);
    const window = instance.windows.getPtr(handle);

    const native: Window.Native = blk: {
        if (comptime builtin.os.tag == .windows) {
            break :blk .{ .win32 = try .init(.{ .handle = handle }, params) };
        }

        return error.UnsupportedPlatform;
    };

    errdefer comptime unreachable;

    window.* = .{
        .handle = native,
        .title = params.title,
        .width = params.width,
        .height = params.height,
        .should_close = false,
    };

    return .{
        .handle = handle,
    };
}

pub fn deinit(self: WindowHandle) void {
    core.asserts.isOnThread(instance.main_thread);

    const window = instance.windows.getPtr(self.handle);

    switch (window.handle) {
        inline else => |*platform| {
            platform.deinit();
        },
    }

    instance.windows.swapRemove(self.handle);
}

pub fn shouldClose(self: WindowHandle) bool {
    return instance.windows.getPtr(self.handle).should_close;
}

pub fn getSize(self: WindowHandle) core.Vec2u32 {
    const window = instance.windows.getPtr(self.handle);
    return .init(window.width, window.height);
}

pub fn setSize(self: WindowHandle, size: core.Vec2u32) void {
    _ = self; // autofix
    _ = size; // autofix
}

pub fn maximize(self: WindowHandle) void {
    _ = self; // autofix
}

pub fn minimize(self: WindowHandle) void {
    _ = self; // autofix
}
