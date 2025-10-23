/// Represents a monitor connected to the system
/// Should only be used internally, to access properties use 'MonitorHandle' functions
/// The native monitor handle
handle: Native,
/// The monitor's user friendly name
name: String,
/// Whther the monitor is connected or not
connected: bool,
/// Whether the monitor is the primary monitor
primary: bool,

const String = @import("core").StringTable.String;
const Win32Monitor = @import("Win32Monitor.zig");

/// The native monitor handle for each platform
pub const Native = union(enum) {
    /// Windows monitor handle
    windows: Win32Monitor,
};
