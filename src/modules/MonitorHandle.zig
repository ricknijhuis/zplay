const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");

const Context = @import("Context.zig");
const Win32Monitor = @import("Win32Monitor.zig");
const WindowHandle = @import("WindowHandle.zig");
const StringTable = core.StringTable;
const String = StringTable.String;
const HandleSet = core.HandleSet;
const Handle = HandleSet(Monitor).Handle;
const Rect = core.Rect(u32);

const MonitorHandle = @This();

/// Represents a monitor connected to the system
/// Should only be used internally, to access properties use 'MonitorHandle' functions
pub const Monitor = struct {
    /// The native monitor handle
    handle: Native,
    /// The monitor's user friendly name
    name: String,
    /// Whther the monitor is connected or not
    connected: bool,
    /// Whether the monitor is the primary monitor
    primary: bool,
};

/// The native monitor handle for each platform
const Native = union(enum) {
    /// Windows monitor handle
    win32: Win32Monitor,
};

/// A way to retrieve monitor handles from native monitors
/// Index 0 is always the primary monitor
pub var monitors: HandleSet(Monitor) = .empty;

/// The handle to 'Monitor' in the HandleSet
handle: Handle,

/// Returns the primary monitor, defined as the monitor with 0, 0 as top left origin.
/// If no primary monitor handle is cached, it queries the OS for it and caches it.
pub fn primary() !MonitorHandle {
    if (monitors.count == 0)
        try poll();

    for (monitors.handles()) |handle| {
        const monitor = monitors.getPtr(handle.handle);
        if (monitor.primary) {
            return handle;
        }
    }
}

/// Returns all monitor handles connected to the system.
pub fn all() ![]MonitorHandle {
    if (monitors.count == 0)
        try poll();

    return monitors.handlesTo(MonitorHandle);
}

/// Returns the monitor handle closest to the given window, if the window is shown on two
/// seperate monitors, it returns the one with the biggest area covered by the window.
pub fn closest(window: WindowHandle) MonitorHandle {
    _ = window; // autofix
}

/// Returns the device name of the monitor.
pub fn getName(self: MonitorHandle) []const u8 {
    const strings = Context.instance.strings;
    const monitor = monitors.getPtr(self.handle);
    return strings.getSlice(monitor.name);
}

/// Returns the work area of the monitor, excluding taskbars and docked windows.
pub fn getWorkArea(self: MonitorHandle) Rect {
    _ = self; // autofix
}

pub fn poll() !void {
    core.asserts.isOnThread(Context.instance.main_thread_id);

    switch (builtin.os.tag) {
        .windows => {
            try Win32Monitor.poll();
        },
        else => return error.UnsupportedPlatform,
    }
}
