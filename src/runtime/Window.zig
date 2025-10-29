//! Represents a window
//! Should only be used internally, to access properties use 'WindowHandle' functions
const builtin = @import("builtin");

/// The native window handle
native: Native,
title: []const u8,
width: u32,
height: u32,
should_close: bool,

pub const Native = switch (builtin.os.tag) {
    .windows => @import("win32/Win32Window.zig"),
    else => @compileError("Platform not 'yet' supported"),
};
