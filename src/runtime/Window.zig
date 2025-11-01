const std = @import("std");
const core = @import("core");
const pl = @import("platform");
const ctx = @import("context.zig");

const WindowHandle = @import("WindowHandle.zig");
const MonitorHandle = @import("MonitorHandle.zig");
const Allocator = std.mem.Allocator;
const String = core.StringTable.String;

const instance = &ctx.instance;

/// Includes MonitorHandle.QueryMonitorError because creating a window in borderless or fullscreen mode
/// requires querying monitor information, which may fail.
pub const CreateWindowError = error{
    NativeWindowCreationFailed,
}; // || MonitorHandle.QueryMonitorError;

pub const Error = Allocator.Error || CreateWindowError;

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
    borderless: MonitorHandle,
    /// An exclusive fullscreen window that takes over the entire screen of the given monitor.
    fullscreen: MonitorHandle,
};

/// Parameters for creation a new window.
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

const Window = @This();

/// The native window handle
native: pl.Window,
title: String,
width: u32,
height: u32,
should_close: bool,

/// Creates a new window with the given initialization parameters.
pub fn create(params: InitParams) !WindowHandle {
    core.asserts.isOnThread(instance.main_thread);

    std.log.info("Creating window", .{});

    const handle = try instance.windows.addOneExact(instance.gpa);
    var self = instance.windows.getPtr(handle);

    self.native = try .create(instance.gpa, params.title);
    self.native.setUserPointer(self);

    switch (params.mode) {
        .windowed => |state| {
            switch (state) {
                .normal => {
                    self.native.resize(params.width, params.height);
                    self.native.show();
                    self.native.focus();
                },
                .minimized => {
                    self.native.resize(params.width, params.height);
                    self.native.minimize();
                },
                .maximized => {
                    self.native.resize(params.width, params.height);
                    self.native.maximize();
                    self.native.show();
                    self.native.focus();
                },
                .hidden => {
                    self.native.resize(params.width, params.height);
                    self.native.hide();
                },
            }
        },
        .borderless, .fullscreen => |monitor_handle| {
            const monitor = instance.monitors.getPtr(monitor_handle.value);

            try switch (params.mode) {
                .borderless => self.native.borderless(&monitor.native),
                .fullscreen => self.native.fullscreen(&monitor.native),
                else => {},
            };

            self.native.show();
            self.native.focus();
        },
    }

    self.title = try instance.strings.getOrPut(instance.gpa, params.title);
    self.width = params.width;
    self.height = params.height;
    self.should_close = false;

    return .{ .value = handle };
}

/// Destroys the window associated with the given handle and frees its resources.
pub fn destroy(handle: WindowHandle) void {
    core.asserts.isOnThread(instance.main_thread);

    var self = instance.windows.getPtr(handle.value);
    self.native.destroy();

    instance.windows.swapRemove(handle.value);
}
