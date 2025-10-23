/// Represents a window
/// Should only be used internally, to access properties use 'WindowHandle' functions
handle: Native,
title: []const u8,
width: u32,
height: u32,
should_close: bool,

const Win32Window = @import("Win32Window.zig");

pub const Native = union(enum) {
    windows: Win32Window,
};
