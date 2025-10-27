//! Provides an abstraction over platform-specific monitor handles and functionality.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const context = @import("context.zig");
const errors = core.errors;

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

/// Errors that can occur when polling for monitors.
pub const PollMonitorError = std.mem.Allocator.Error || error{
    /// No monitors were found on the system. This either means no monitors are connected or a bug occurred while querying the OS.
    NoMonitorsFound,
    /// A monitor could not be created due to an unknown error.
    /// On windows this can occur when conversion between UTF-16 and UTF-8 fails.
    MonitorNotCreated,
};

/// Errors that can occur when querying for a specific monitor.
pub const QueryMonitorError = error{
    /// The handle was not valid or could not be found in the handle set or by the OS.
    MonitorNotFound,
};

/// Represents information about a display mode supported by a monitor.
pub const DisplayInfo = struct {
    size: core.Vec2u32,
    refresh_rate: u32,
};

/// All possible errors that can occur when dealing with monitors.
pub const Error = std.mem.Allocator.Error || PollMonitorError || QueryMonitorError;

/// The handle to 'Monitor' in the HandleSet
handle: Handle,

/// Returns the primary monitor, defined as the monitor with 0, 0 as top left origin.
/// If no primary monitor handle is cached, it queries the OS for it and caches it.
/// If no primary monitor is found, it returns the first monitor found.
/// If no monitors are found, it returns 'NoMonitorsFound'.
/// If out of memory occurs, it returns 'OutOfMemory'.
pub fn primary() Error!MonitorHandle {
    core.asserts.isOnThread(instance.main_thread);

    const handles = try all();
    const native_primary = try Monitor.Native.primary();

    for (handles) |handle| {
        const monitor = instance.monitors.getPtr(handle.handle);
        if (monitor.native.monitor == native_primary) {
            return handle;
        }
    }

    // Fallback to first monitor if no primary found
    return handles[0];
}

/// Returns all monitor handles connected to the system.
pub fn all() PollMonitorError![]MonitorHandle {
    if (instance.monitors.count == 0)
        try poll();

    try errors.throwIfZero(instance.monitors.count, PollMonitorError.NoMonitorsFound, "No monitors found");

    return instance.monitors.handlesTo(MonitorHandle);
}

/// Returns the monitor handle closest to the given window, if the window is shown on two
/// seperate monitors, it returns the one with the biggest area covered by the window.
pub fn closest(window_handle: WindowHandle) Error!MonitorHandle {
    const window = instance.windows.getPtr(window_handle.handle);
    const monitors = try all();

    const native_window = window.native;
    const native_monitor = try Monitor.Native.closest(native_window);

    for (monitors) |monitor_handle| {
        const monitor = instance.monitors.getPtr(monitor_handle.handle);
        if (monitor.native.monitor == native_monitor) {
            return monitor_handle;
        }
    }

    return errors.throw(Error.MonitorNotFound, "No monitor found");
}

/// Returns the device name of the monitor.
pub fn getName(self: MonitorHandle) []const u8 {
    const monitor = instance.monitors.getPtr(self.handle);
    return instance.strings.getSlice(monitor.name);
}

/// Returns the work area of the monitor, excluding taskbars and docked windows.
pub fn getWorkArea(self: MonitorHandle) QueryMonitorError!Rect(i32) {
    core.asserts.isOnThread(instance.main_thread);

    const monitor = instance.monitors.getPtr(self.handle);
    return monitor.native.getWorkArea();
}

/// Returns the full area of the monitor, including taskbars and docked windows.
pub fn getFullArea(self: MonitorHandle) QueryMonitorError!Rect(i32) {
    core.asserts.isOnThread(instance.main_thread);

    const monitor = instance.monitors.getPtr(self.handle);
    return monitor.native.getFullArea();
}

/// Returns the display information of the monitor, including size and refresh rate.
pub fn getDisplayInfo(self: MonitorHandle) QueryMonitorError!DisplayInfo {
    core.asserts.isOnThread(instance.main_thread);

    const monitor = instance.monitors.getPtr(self.handle);
    return monitor.native.getDisplayInfo();
}

/// Sets the display size of the monitor.
pub fn setDisplaySize(self: MonitorHandle, size: core.Vec2u32) QueryMonitorError!void {
    core.asserts.isOnThread(instance.main_thread);

    const monitor = instance.monitors.getPtr(self.handle);
    return monitor.native.setDisplaySize(size);
}

/// Polls the operating system for connected monitors and updates the internal monitor list.
pub fn poll() PollMonitorError!void {
    core.asserts.isOnThread(instance.main_thread);

    try Monitor.Native.poll();
}
