const std = @import("std");
const core = @import("core");
const context = @import("context.zig");
const c = @import("win32").everything;
const mem = std.mem;

const utf16ToUtf8 = std.unicode.utf16LeToUtf8AllocZ;

const MonitorHandle = @import("MonitorHandle.zig");
const Monitor = @import("Monitor.zig");
const Win32Window = @import("Win32Window.zig");
const String = core.StringTable.String;

const Win32Monitor = @This();

const instance = &context.instance;

monitor: c.HMONITOR,
adapter: [32]u16,
name: [128]u16,

pub fn primary() !Win32Monitor {
    const top_left: c.POINT = .{ .x = 0, .y = 0 };
    const monitor = c.MonitorFromPoint(top_left, c.MONITOR_DEFAULTTOPRIMARY);

    return .{
        .monitor = monitor,
    };
}

pub fn closest(window: Win32Window) !Win32Monitor {
    const monitor = c.MonitorFromWindow(window.window, c.MONITOR_DEFAULTTONEAREST);

    return .{
        .monitor = monitor,
    };
}

/// Polls the system for connected monitors and updates the monitor handles accordingly.
pub fn poll() !void {
    // Any existing monitors might have been disconnected since last query
    // if not connected we change their state to disconnected.
    // if connected we set the handle to none.
    // Assume no more than 16 monitors for now, which is a lot.
    var possible_disconnected: []MonitorHandle = &.{};
    possible_disconnected.len = instance.monitors.count;
    @memcpy(possible_disconnected, instance.monitors.handlesTo(MonitorHandle));

    var adapter: c.DISPLAY_DEVICEW = undefined;
    var device: c.DISPLAY_DEVICEW = undefined;
    var adapter_index: u32 = 0;

    while (true) : (adapter_index += 1) {
        var is_primary: bool = false;
        adapter = mem.zeroes(c.DISPLAY_DEVICEW);
        adapter.cb = @sizeOf(c.DISPLAY_DEVICEW);

        // Get the display adapters, if
        if (c.EnumDisplayDevicesW(null, adapter_index, &adapter, 0) == 0)
            break;

        // Skip inactive adapters
        if ((adapter.StateFlags & c.DISPLAY_DEVICE_ACTIVE) == 0)
            continue;

        if ((adapter.StateFlags & c.DISPLAY_DEVICE_PRIMARY_DEVICE) != 0)
            is_primary = true;

        var device_index: u32 = 0;
        while (true) : (device_index += 1) {
            device = mem.zeroes(c.DISPLAY_DEVICEW);
            device.cb = @sizeOf(c.DISPLAY_DEVICEW);

            if (c.EnumDisplayDevicesW(@ptrCast(&adapter.DeviceName[0]), device_index, &device, 0) == 0)
                break;

            if ((device.StateFlags & c.DISPLAY_DEVICE_ACTIVE) == 0)
                continue;

            var i: u32 = 0;
            for (possible_disconnected[0..]) |*handle| {
                if (handle.handle != .none) {
                    const monitor = instance.monitors.getPtr(handle.handle);
                    // If eql, device is still connected but might need updating
                    if (std.mem.eql(u16, &monitor.handle.win32.name, &device.DeviceName)) {
                        monitor.connected = true;
                        monitor.primary = is_primary;

                        // Set the handle to none to mark it as found
                        handle.handle = .none;

                        // Update handle as that might have changed
                        _ = c.EnumDisplayMonitors(null, null, monitorCallback, @intCast(@intFromPtr(monitor)));
                        break;
                    }
                }
                i += 1;
            }

            // The monitor already existed, skip adding a new one
            if (i < instance.monitors.count)
                continue;

            const new_monitor_handle = try instance.monitors.addOne(instance.gpa);
            var new_monitor = instance.monitors.getPtr(new_monitor_handle);

            if (c.EnumDisplayMonitors(null, null, monitorCallback, @intCast(@intFromPtr(new_monitor))) == 0) {
                instance.monitors.swapRemove(new_monitor_handle);
            }

            const utf16_name: [:0]const u16 = std.mem.span(@as([*:0]u16, @ptrCast(&device.DeviceString)));
            const utf8_name = try utf16ToUtf8(instance.gpa, utf16_name);
            const name = try instance.strings.getOrPut(instance.gpa, utf8_name);
            new_monitor.name = name;
            new_monitor.connected = true;
            new_monitor.primary = is_primary;

            @memcpy(&new_monitor.handle.win32.name, &device.DeviceString);
            @memcpy(&new_monitor.handle.win32.adapter, &device.DeviceName);
        }
    }
}

fn monitorCallback(
    monitor: ?c.HMONITOR,
    hdc: ?c.HDC,
    rect: ?*c.RECT,
    data: c.LPARAM,
) callconv(.c) c.BOOL {
    _ = rect;
    _ = hdc;
    if (monitor) |mon| {
        const monitor_ptr: *Monitor = @ptrFromInt(@as(usize, @intCast(data)));
        monitor_ptr.handle.win32.monitor = mon;
    }

    return c.TRUE;
}
