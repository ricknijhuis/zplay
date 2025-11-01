const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const debug = std.debug;
const meta = std.meta;
const testing = std.testing;

/// Information about a display/monitor.
pub const DisplayInfo = struct {
    pub const empty: DisplayInfo = .{
        .width = 0,
        .height = 0,
        .refresh_rate = 0,
    };

    size: core.Vec2u32,
    refresh_rate: u32,
};

/// Callbacks for platform events, set by the runtime, called by the platform layer.
pub const Callbacks = struct {
    pub const OnResize = *const fn (window: Window, width: u32, height: u32) void;
    pub const OnClose = *const fn (window: Window) void;
    pub const OnDisplayChange = *const fn () void;
    // TODO: Add focused window
    pub const OnKeyboardEvent = *const fn (keyboard: Keyboard, scancode: Keyboard.Scancode, down: bool) void;

    onResize: OnResize,
    onClose: OnClose,
    onDisplayChange: OnDisplayChange,
    onKeyboardEvent: OnKeyboardEvent,
};

// Global callbacks for platform events, set by the runtime, called by the platform layer.
// Required to be set.
pub var callbacks: Callbacks = .{
    .onResize = undefined,
    .onClose = undefined,
    .onDisplayChange = undefined,
    .onKeyboardEvent = undefined,
};

/// Platform-specific window implementation
pub const Window = switch (builtin.os.tag) {
    .windows => @import("win32/Window.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

/// Platform-specific event implementation
pub const Event = switch (builtin.os.tag) {
    .windows => @import("win32/Event.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

/// Platform-specific monitor implementation
pub const Monitor = switch (builtin.os.tag) {
    .windows => @import("win32/Monitor.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

/// Platform-specific keyboard implementation
pub const Keyboard = switch (builtin.os.tag) {
    .windows => @import("win32/Keyboard.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
