const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const app = @import("app.zig");
const wnd = @import("window.zig");

const Allocator = std.mem.Allocator;
const HandleSet = core.HandleSet;
const Window = wnd.Window;

pub const Internal = struct {
    pub const Impl = switch (builtin.os.tag) {
        .windows => @import("win32/Monitor.zig"),
        else => @compileError("Platform not 'yet' supported"),
    };

    pub const Id = core.Id(Internal);

    impl: Impl,
    id: Id,
    bounds: core.Rect(i32),
    connected: bool,
};

pub const Monitor = struct {
    const HandleT = HandleSet(Internal).Handle;

    const instance = &app.Internal.instance;

    handle: HandleT,

    /// Polls the system for connected monitors and updates the internal list.
    pub fn poll(gpa: Allocator) !void {
        var it = Internal.Impl.iterate();
        var monitor: Internal = undefined;

        // Mark all existing monitors as disconnected
        for (instance.monitors.items) |*mntr| {
            mntr.connected = false;
        }

        // Iterate over all connected monitors
        // If a monitor already exists, update its native info and mark it as connected
        while (it.next(&monitor)) {
            var exists = false;

            for (instance.monitors.items) |*mntr| {
                if (Internal.Impl.equals(mntr, &monitor)) {
                    // Monitor already exists, info
                    mntr.* = monitor;
                    exists = true;
                    break;
                }
            }

            if (exists) continue;

            // std.log.info("Monitor: {any}", .{monitor});

            const handle = try instance.monitors.addOneExact(gpa);
            const new_monitor = instance.monitors.getPtr(handle);
            new_monitor.* = monitor;
            new_monitor.id = .generate();
        }
    }

    /// Compares two monitors for equality based on their internal IDs.
    pub fn equals(a: Monitor, b: Monitor) bool {
        const ma = instance.monitors.getPtr(a.handle);
        const mb = instance.monitors.getPtr(b.handle);
        return ma.id == mb.id;
    }

    /// Returns true if the specified monitor is currently connected.
    pub fn isConnected(monitor: Monitor) bool {
        return instance.monitors.getPtr(monitor.handle).connected;
    }

    /// Returns the bounds of the specified monitor in virtual screen coordinates.
    pub fn getBounds(monitor: Monitor) core.Rect(i32) {
        return instance.monitors.getPtr(monitor.handle).bounds;
    }

    /// Returns the primary monitor (the one at position 0,0).
    pub fn primary() ?Monitor {
        if (instance.monitors.count == 0) {
            return null;
        }
        for (instance.monitors.handlesTo(Monitor), instance.monitors.items) |handle, *mntr| {
            if (mntr.bounds.position.x() == 0 and mntr.bounds.position.y() == 0) {
                return handle;
            }
        }

        return .{ .handle = .fromRaw(instance.monitors.dense[0]) };
    }

    /// Returns the monitor that is closest to the specified window.
    /// Closest is determined by the largest overlapping area.
    pub fn closest(handle: Window) ?Monitor {
        const window = app.Internal.instance.windows.getPtr(handle.handle);
        var best_monitor: ?Monitor = null;
        var best_area: i32 = 0;

        for (app.Internal.instance.monitors.handlesTo(Monitor), app.Internal.instance.monitors.items) |monitor_handle, *monitor| {
            const area = window.full.intersection(monitor.bounds);
            if (area > best_area) {
                best_area = area;
                best_monitor = monitor_handle;
            }
        }

        return best_monitor;
    }
};
