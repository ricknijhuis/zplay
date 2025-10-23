const builtin = @import("builtin");
const core = @import("core");

const Context = @import("Context.zig");
const Win32Window = @import("Win32Window.zig");
const HandleSet = core.HandleSet;
const Handle = HandleSet(Window).Handle;

const WindowHandle = @This();

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

const Native = union(enum) {
    win32: Win32Window,
};

/// Represents a window
/// Should only be used internally, to access properties use 'WindowHandle' functions
pub const Window = struct {
    handle: Native,
    mode: Mode,
    title: []const u8,
    width: u32,
    height: u32,
    should_close: bool,
};

pub var windows: HandleSet(Window) = .empty;

handle: Handle = .none,

pub fn init(params: InitParams) !WindowHandle {
    core.asserts.isOnThread(Context.instance.main_thread_id);

    const gpa = Context.instance.gpa;
    const handle = try windows.addOneExact(gpa);
    const window = windows.getPtr(handle);

    const native: Native = blk: {
        if (comptime builtin.os.tag == .windows) {
            break :blk .{ .win32 = try .init(.{ .handle = handle }, params) };
        }

        return error.UnsupportedPlatform;
    };

    errdefer comptime unreachable;

    window.* = .{
        .handle = native,
        .mode = params.mode,
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
    core.asserts.isOnThread(Context.instance.main_thread_id);

    const window = windows.getPtr(self.handle);

    switch (window.handle) {
        inline else => |*platform| {
            platform.deinit();
        },
    }

    windows.swapRemove(self.handle);

    if (windows.count == 0) {
        windows.deinit(Context.instance.gpa);
    }
}

pub fn shouldClose(self: WindowHandle) bool {
    return windows.getPtr(self.handle).should_close;
}

pub fn getSize(self: WindowHandle) core.Vec2u32 {
    const window = windows.getPtr(self.handle);
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
