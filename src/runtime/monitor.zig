const core = @import("core");
const pl = @import("platform");
const app = @import("app.zig");
const gpa = @import("gpa.zig");
const wnd = @import("window.zig");
const asserts = core.asserts;
const errors = core.errors;

const Rect = core.Rect;
const HandleSet = core.HandleSet;
const Window = wnd.Window;

/// Information about the display properties of a monitor.
pub const DisplayInfo = pl.DisplayInfo;

/// Errors related to querying or setting monitor properties.
pub const Error = pl.Monitor.Error;

/// For internal use. Is not exposed through root.zig
pub const Internal = struct {
    pub var instance: HandleSet(Internal) = undefined;

    native: pl.Monitor,
    connected: bool,

    pub fn init() !void {
        instance = .empty;
    }

    pub fn deinit() void {
        instance.deinit(gpa.Internal.instance);
    }

    /// Polls the system for connected monitors and updates the internal monitor list.
    /// If a monitor is newly connected, it is added to the list.
    /// If a monitor is disconnected, it is marked as such.
    pub fn poll() !void {
        var it = pl.Monitor.iterate();
        var native: pl.Monitor = undefined;

        // Mark all existing monitors as disconnected
        for (Internal.instance.items) |*monitor| {
            monitor.connected = false;
        }

        // Iterate over all connected monitors
        // If a monitor already exists, update its native info and mark it as connected
        while (it.next(&native)) {
            var exists = false;
            for (Internal.instance.items) |*monitor| {
                if (monitor.native.equals(&native)) {
                    // Monitor already exists, update native info
                    monitor.native = native;
                    monitor.connected = true;
                    exists = true;
                    break;
                }
            }

            if (exists) continue;

            const handle = try Internal.instance.addOneExact(gpa.Internal.instance);
            const monitor = Internal.instance.getPtr(handle);
            monitor.native = native;
            monitor.connected = true;
        }
    }
};

/// Represents a handle to a monitor
pub const Monitor = struct {
    const HandleT = HandleSet(Internal).Handle;

    /// The actual handle value
    value: HandleT,

    /// Returns the primary monitor handle, meaning the monitor
    /// at position (0, 0) in a multi-monitor setup.
    pub fn primary() !Monitor {
        const handles = try all();
        const primary_native = try pl.Monitor.primary();

        if (searchByNative(handles, primary_native)) |found| {
            return found;
        }

        return handles[0];
    }

    /// Returns the monitor handle that is closest to the given window.
    pub fn closest(handle: Window) !Monitor {
        const handles = try all();
        const window = wnd.Internal.instance.getPtr(handle.value);
        const closest_native = try pl.Monitor.closest(&window.native);

        if (searchByNative(handles, closest_native)) |found| {
            return found;
        }

        return handles[0];
    }

    /// Returns all monitor handles connected to the system.
    pub fn all() ![]Monitor {
        if (Internal.instance.count == 0) {
            try Internal.poll();
        }

        try errors.throwIfZero(Internal.instance.count, error.MonitorNotFound, "No monitors found");

        return Internal.instance.handlesTo(Monitor);
    }

    /// Returns true if the monitor is currently connected.
    pub fn isConnected(self: Monitor) bool {
        const monitor = Internal.instance.getPtr(self.value);
        return monitor.connected;
    }

    /// Returns the work area of the monitor, excluding taskbars and docked windows.
    /// Returns error if given monitor is not found
    pub fn getWorkArea(self: Monitor) Error!Rect(i32) {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const monitor = Internal.instance.getPtr(self.value);
        return monitor.native.getWorkArea();
    }

    /// Returns the full area of the monitor, including taskbars and docked windows.
    /// Returns error if given monitor is not found
    pub fn getFullArea(self: Monitor) Error!Rect(i32) {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const monitor = Internal.instance.getPtr(self.value);
        return monitor.native.getFullArea();
    }

    /// Returns the display information of the monitor, including size and refresh rate.
    /// Returns error if given monitor is not found
    pub fn getDisplayInfo(self: Monitor) Error!DisplayInfo {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const monitor = Internal.instance.getPtr(self.value);
        return monitor.native.getDisplayInfo();
    }

    /// Sets the display size of the monitor.
    /// Returns error if given monitor is not found
    pub fn setDisplaySize(self: Monitor, size: core.Vec2u32) Error!void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const monitor = Internal.instance.getPtr(self.value);
        return monitor.native.setDisplaySize(size);
    }

    fn searchByNative(values: []const Monitor, needle: anytype) ?Monitor {
        for (values) |handle| {
            const monitor = Internal.instance.getPtr(handle.value);
            if (monitor.native.equals(needle)) {
                return handle;
            }
        }
        return null;
    }
    pub fn isValid(self: Monitor) bool {
        return Internal.instance.contains(self.value);
    }
};
