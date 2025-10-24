const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const context = @import("context.zig");

const Monitor = @import("Monitor.zig");
const Win32Monitor = @import("Win32Monitor.zig");
const WindowHandle = @import("WindowHandle.zig");
const HandleSet = core.HandleSet;
const StringTable = core.StringTable;
const Rect = core.Rect;
const Handle = HandleSet(Monitor).Handle;
const String = StringTable.String;

const MonitorHandle = @This();

const instance = &context.instance;

/// The handle to 'Monitor' in the HandleSet
handle: Handle,

/// Returns the primary monitor, defined as the monitor with 0, 0 as top left origin.
/// If no primary monitor handle is cached, it queries the OS for it and caches it.
pub fn primary() !MonitorHandle {
    if (instance.monitors.count == 0)
        try poll();

    for (instance.monitors.handles()) |handle| {
        const monitor = instance.monitors.getPtr(handle.handle);
        if (monitor.primary) {
            return handle;
        }
    }
}

/// Returns all monitor handles connected to the system.
pub fn all() ![]MonitorHandle {
    if (instance.monitors.count == 0)
        try poll();

    return instance.monitors.handlesTo(MonitorHandle);
}

/// Returns the monitor handle closest to the given window, if the window is shown on two
/// seperate monitors, it returns the one with the biggest area covered by the window.
pub fn closest(window: WindowHandle) MonitorHandle {
    _ = window; // autofix
}

/// Returns the device name of the monitor.
pub fn getName(self: MonitorHandle) []const u8 {
    const monitor = instance.monitors.getPtr(self.handle);
    return instance.strings.getSlice(monitor.name);
}

/// Returns the work area of the monitor, excluding taskbars and docked windows.
pub fn getWorkArea(self: MonitorHandle) Rect(i32) {
    core.asserts.isOnThread(instance.main_thread);

    const monitor = instance.monitors.getPtr(self.handle);
    return switch (monitor.handle) {
        inline else => |*native| {
            return native.getWorkArea();
        },
    };
}

pub fn poll() !void {
    core.asserts.isOnThread(instance.main_thread);

    switch (builtin.os.tag) {
        .windows => {
            try Win32Monitor.poll();
        },
        else => return error.UnsupportedPlatform,
    }
}
