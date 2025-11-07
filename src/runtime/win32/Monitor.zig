const std = @import("std");
const mem = std.mem;

const c = @import("win32").everything;
const core = @import("core");
const errors = core.errors;

const mntr = @import("../monitor.zig");

const Win32Monitor = @This();

pub const Error = error{Win32MonitorNotFound};

handle: c.HMONITOR,
adapter: [32]u16,
name: [128]u16,

pub fn getBounds(self: *const mntr.Internal) error.Win32MonitorNotFound!core.Rect(i32) {
    var info: c.MONITORINFO = std.mem.zeroes(c.MONITORINFO);
    info.cbSize = @sizeOf(c.MONITORINFO);

    errors.throwIfZero(c.GetMonitorInfoW(self.impl.handle, @ptrCast(&info)), Error.Win32MonitorNotFound, "Failed to get monitor info");

    return core.Rect(i32){
        .x = info.rcMonitor.left,
        .y = info.rcMonitor.top,
        .width = info.rcMonitor.right - info.rcMonitor.left,
        .height = info.rcMonitor.bottom - info.rcMonitor.top,
    };
}

/// Depending on other type compares monitor by name or by native handle.
/// This allows for easy searching of monitors for different use-cases and platforms.
// TODO: Maybe find a better way to do this without anytype?
// challenge here is all platforms need to have same function signature for Monitor equality check
pub fn equals(self: *const mntr.Internal, other: anytype) bool {
    if (@TypeOf(other) == @TypeOf(self)) {
        return std.mem.eql(u16, &self.impl.name, &other.impl.name);
    }

    if (@TypeOf(other) == @TypeOf(self.impl.handle)) {
        return self.impl.handle == other;
    }

    return false;
}

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
    pub fn next(self: *Iterator, out_monitor: *mntr.Internal) bool {
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

                out_monitor.impl.name = device.DeviceString;
                out_monitor.impl.adapter = adapter.DeviceName;

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
        const monitor_ptr: *mntr.Internal = @ptrFromInt(@as(usize, @intCast(data)));

        // std.log.info("found: {any}, {any}", .{ info, monitor_ptr });
        if (mem.eql(u16, &monitor_ptr.impl.adapter, &info.szDevice)) {
            // Docs mention monitor can never be null: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-monitorenumproc
            monitor_ptr.impl.handle = monitor.?;
            monitor_ptr.connected = true;
            monitor_ptr.bounds = .init(
                info.monitorInfo.rcMonitor.left,
                info.monitorInfo.rcMonitor.top,
                info.monitorInfo.rcMonitor.right - info.monitorInfo.rcMonitor.left,
                info.monitorInfo.rcMonitor.bottom - info.monitorInfo.rcMonitor.top,
            );
        }
    }

    return c.TRUE;
}
