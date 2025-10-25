//! Represents a monitor connected to the system
//! Should only be used internally, to access properties use 'MonitorHandle' functions
const builtin = @import("builtin");

/// The native monitor handle
native: Native,
/// The monitor's user friendly name
name: String,
/// Whther the monitor is connected or not
connected: bool,
/// Whether the monitor is the primary monitor
primary: bool,

const String = @import("core").StringTable.String;

pub const Native = switch (builtin.os.tag) {
    .windows => @import("Win32Monitor.zig"),
    else => @compileError("Platform not 'yet' supported"),
};
