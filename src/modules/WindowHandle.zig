//! Provides an abstraction over platform-specific monitor handles and functionality.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");

const context = @import("context.zig");
const Win32Window = @import("Win32Window.zig");
const Window = @import("Window.zig");
const MonitorHandle = @import("MonitorHandle.zig");
const HandleSet = core.HandleSet;
const Handle = HandleSet(Window).Handle;

const WindowHandle = @This();

const instance = &context.instance;

pub const CreateWindowError = error{
    NativeWindowCreationFailed,
};

pub const Error = std.mem.Allocator.Error || CreateWindowError;

pub const ModeType = enum {
    /// A standard window with borders and title bar using the given size.
    windowed,
    /// A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
    borderless,
    /// An exclusive fullscreen window that takes over the entire screen of the given monitor.
    fullscreen,
};

pub const ModeState = enum {
    /// A standard window state with borders and title bar using the given size.
    normal,
    /// A minimized window state, typically represented as an icon in the taskbar or dock.
    minimized,
    /// A maximized window state that fills the screen without going into fullscreen mode.
    maximized,
    /// A hidden window state that is not visible to the user.
    hidden,
};

pub const Mode = union(ModeType) {
    /// A standard window with borders and title bar.
    windowed: ModeState,
    /// A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
    borderless: ModeState,
    /// An exclusive fullscreen window that takes over the entire screen of the given monitor.
    fullscreen: MonitorHandle,
};

/// Parameters for initializing a new window.
pub const InitParams = struct {
    /// The mode in which to create the window.
    mode: Mode,
    /// Title of the window.
    title: []const u8,
    /// Width of the window in pixels, only used for windowed and borderless modes.
    width: u32,
    /// Height of the window in pixels, only used for windowed and borderless modes.
    height: u32,
};

handle: Handle = .none,

/// Initializes a new window with the given parameters.
/// Returns a handle to the created window.
// TODO: Support other platforms besides Windows.
// TODO: Supply error set.
pub fn init(params: InitParams) Error!WindowHandle {
    core.asserts.isOnThread(instance.main_thread);

    const gpa = instance.gpa;
    const handle = try instance.windows.addOneExact(gpa);
    const window = instance.windows.getPtr(handle);

    const native: Window.Native = blk: {
        if (comptime builtin.os.tag == .windows) {
            break :blk .{ .windows = try .init(.{ .handle = handle }, params) };
        }

        @compileError("Platform not 'yet' supported");
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

/// Deinitializes the window and frees its resources.
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

/// Returns true if the window has been requested to close.
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

/// Maximizes the window to fill the screen, without going into fullscreen mode.
pub fn maximize(self: WindowHandle) void {
    const window = instance.windows.getPtr(self.handle);
    switch (window.handle) {
        inline else => |*platform| {
            platform.maximize();
        },
    }
}

/// Restores the window to its previous size and position before being maximized or minimized.
pub fn restore(self: WindowHandle) void {
    const window = instance.windows.getPtr(self.handle);
    switch (window.handle) {
        inline else => |*platform| {
            platform.restore();
        },
    }
}

/// Minimizes the window to the taskbar or dock.
pub fn minimize(self: WindowHandle) void {
    const window = instance.windows.getPtr(self.handle);
    switch (window.handle) {
        inline else => |*platform| {
            platform.minimize();
        },
    }
}
