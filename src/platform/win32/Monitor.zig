const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;
const pl = @import("../root.zig");
const mem = std.mem;
const errors = core.errors;
const utf16ToUtf8 = std.unicode.utf16LeToUtf8AllocZ;

const Window = @import("Window.zig");
const Rect = core.Rect;
const Monitor = @This();

pub const Handle = c.HMONITOR;

pub const Error = error{
    MonitorNotFound,
};

handle: Handle,
adapter: [32]u16,
name: [128]u16,

pub fn primary() Error!Handle {
    const top_left: c.POINT = .{ .x = 0, .y = 0 };
    const monitor = c.MonitorFromPoint(top_left, c.MONITOR_DEFAULTTOPRIMARY);

    return errors.throwIfNull(monitor, Error.MonitorNotFound, "Primary monitor not found");
}

pub fn closest(window: *Window) Error!Handle {
    const monitor = c.MonitorFromWindow(window.handle, c.MONITOR_DEFAULTTONEAREST);
    return errors.throwIfNull(monitor, Error.MonitorNotFound, "Monitor not found by window handle");
}

pub fn getWorkArea(self: *const Monitor) Error!Rect(i32) {
    var monitor_info: c.MONITORINFO = std.mem.zeroes(c.MONITORINFO);
    monitor_info.cbSize = @sizeOf(c.MONITORINFO);

    try errors.throwIfZero(c.GetMonitorInfoW(self.handle, &monitor_info), Error.MonitorNotFound, "Monitor not found");

    return .{
        .position = .init(
            @intCast(monitor_info.rcWork.left),
            @intCast(monitor_info.rcWork.top),
        ),
        .size = .init(
            @intCast(monitor_info.rcWork.right - monitor_info.rcWork.left),
            @intCast(monitor_info.rcWork.bottom - monitor_info.rcWork.top),
        ),
    };
}

pub fn getFullArea(self: *const Monitor) Error!Rect(i32) {
    var monitor_info: c.MONITORINFO = std.mem.zeroes(c.MONITORINFO);
    monitor_info.cbSize = @sizeOf(c.MONITORINFO);

    try errors.throwIfZero(c.GetMonitorInfoW(self.handle, &monitor_info), Error.MonitorNotFound, "Monitor not found");

    return .{
        .position = .init(
            @intCast(monitor_info.rcMonitor.left),
            @intCast(monitor_info.rcMonitor.top),
        ),
        .size = .init(
            @intCast(monitor_info.rcMonitor.right - monitor_info.rcMonitor.left),
            @intCast(monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top),
        ),
    };
}

pub fn getDisplayInfo(self: *const Monitor) Error!pl.DisplayInfo {
    var device_mode: c.DEVMODEW = std.mem.zeroes(c.DEVMODEW);
    device_mode.dmSize = @sizeOf(c.DEVMODEW);

    try errors.throwIfZero(
        c.EnumDisplaySettingsW(@ptrCast(&self.adapter), c.ENUM_CURRENT_SETTINGS, &device_mode),
        Error.MonitorNotFound,
        "Monitor not found",
    );

    return .{
        .size = .init(device_mode.dmPelsWidth, device_mode.dmPelsHeight),
        .refresh_rate = device_mode.dmDisplayFrequency,
    };
}

pub fn setDisplaySize(self: *const Monitor, size: core.Vec2u32) Error!void {
    var device_mode: c.DEVMODEW = std.mem.zeroes(c.DEVMODEW);
    device_mode.dmSize = @sizeOf(c.DEVMODEW);
    device_mode.dmPelsWidth = size.x();
    device_mode.dmPelsHeight = size.y();
    device_mode.dmFields = @intCast(c.DM_PELSWIDTH | c.DM_PELSHEIGHT);

    // TODO: Handle other return values
    try errors.throwIfNotTrue(
        c.ChangeDisplaySettingsExW(
            @ptrCast(&self.adapter),
            &device_mode,
            null,
            c.CDS_FULLSCREEN,
            null,
        ) == c.DISP_CHANGE_SUCCESSFUL,
        Error.MonitorNotFound,
        "Failed to change display settings",
    );
}

/// Depending on other type compares monitor by name or by native handle.
/// This allows for easy searching of monitors for different use-cases and platforms.
// TODO: Maybe find a better way to do this without anytype?
// challenge here is all platforms need to have same function signature for Monitor equality check
pub fn equals(self: *const Monitor, other: anytype) bool {
    if (@TypeOf(other) == @TypeOf(self)) {
        return std.mem.eql(u16, &self.name, &other.name);
    }

    if (@TypeOf(other) == @TypeOf(self.handle)) {
        return self.handle == other;
    }

    return false;
}

/// Returns an iterator to enumerate all connected monitors.
pub fn iterate() Iterator {
    return Iterator{
        .adapter_index = 0,
        .monitor_index = 0,
    };
}

/// Iterator to enumerate all connected monitors.
pub const Iterator = struct {
    adapter_index: u32,
    monitor_index: u32,

    /// Advances the iterator to the next connected monitor.
    /// Returns true if a monitor was found, false if no more monitors are available.
    /// If true is returned, out_monitor is populated with the monitor information.
    pub fn next(self: *Iterator, out_monitor: *Monitor) bool {
        var adapter: c.DISPLAY_DEVICEW = undefined;
        var device: c.DISPLAY_DEVICEW = undefined;

        outer: while (true) : ({
            self.adapter_index += 1;
            self.monitor_index = 0;
        }) {
            adapter = mem.zeroes(c.DISPLAY_DEVICEW);
            adapter.cb = @sizeOf(c.DISPLAY_DEVICEW);

            if (c.EnumDisplayDevicesW(null, self.adapter_index, &adapter, 0) == 0) {
                // No more adapters
                return false;
            }

            if ((adapter.StateFlags & c.DISPLAY_DEVICE_ACTIVE) == 0) {
                // Inactive adapter, skip
                continue :outer;
            }

            while (true) : (self.monitor_index += 1) {
                device = mem.zeroes(c.DISPLAY_DEVICEW);
                device.cb = @sizeOf(c.DISPLAY_DEVICEW);

                if (c.EnumDisplayDevicesW(@ptrCast(&adapter.DeviceName[0]), self.monitor_index, &device, 0) == 0) {
                    continue :outer;
                }

                if ((device.StateFlags & c.DISPLAY_DEVICE_ACTIVE) == 0) {
                    // Inactive device, skip
                    continue;
                }

                out_monitor.name = device.DeviceString;
                out_monitor.adapter = adapter.DeviceName;

                // TODO: might need to be called multiple times until false returned? Need to investigate.
                _ = c.EnumDisplayMonitors(null, null, monitorCallback, @intCast(@intFromPtr(out_monitor)));

                self.monitor_index += 1;
                return true;
            }

            return false;
        }
    }
};

fn monitorCallback(
    monitor: ?c.HMONITOR,
    hdc: ?c.HDC,
    rect: ?*c.RECT,
    data: c.LPARAM,
) callconv(.c) c.BOOL {
    _ = hdc; // autofix
    _ = rect; // autofix
    var info: c.MONITORINFOEXW = std.mem.zeroes(c.MONITORINFOEXW);
    info.monitorInfo.cbSize = @sizeOf(c.MONITORINFOEXW);

    if (c.GetMonitorInfoW(monitor, @ptrCast(&info)) != 0) {
        const monitor_ptr: *Monitor = @ptrFromInt(@as(usize, @intCast(data)));

        if (mem.eql(u16, &monitor_ptr.adapter, &info.szDevice)) {
            // Docs mention monitor can never be null: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-monitorenumproc
            monitor_ptr.handle = monitor.?;
        }
    }

    return c.TRUE;
}
