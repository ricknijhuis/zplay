//! Represents a window
//! Should only be used internally, to access properties use 'WindowHandle' functions
const builtin = @import("builtin");

/// The native window handle
native: Native,
title: []const u8,
width: u32,
height: u32,
should_close: bool,

// const Win32Window = @import("Win32Window.zig");

// pub const Native = union(enum) {
//     windows: Win32Window,
// };
pub const Native = switch (builtin.os.tag) {
    .windows => @import("Win32Window.zig"),
    else => @compileError("Platform not 'yet' supported"),
};
