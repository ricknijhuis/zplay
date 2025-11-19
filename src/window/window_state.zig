const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");

const WindowSystem = @import("window_system.zig").WindowSystem;
const Allocator = std.mem.Allocator;
const String = core.StringTable.String;
const Rect = core.Rect;

pub const WindowState = struct {
    /// The Mode defines how the window should be created.
    pub const ModeType = enum {
        /// A standard window with borders and title bar using the given size.
        windowed,
        // A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
        // borderless,
        // An exclusive fullscreen window that takes over the entire screen of the given monitor.
        // fullscreen,
    };

    /// The specific state for the given ModeType.
    pub const ModeState = enum {
        /// A standard window state with borders and title bar using the given size.
        normal,
        /// A minimized window state, typically represented as an icon in the taskbar or dock.
        minimized,
        /// A maximized window state that fills the screen without going into fullscreen mode.
        maximized,
        /// A hidden window state that is not visible to the user.
        hidden,
    };

    /// The Mode union encapsulates the mode type and its associated state or parameters.
    pub const Mode = union(ModeType) {
        /// A standard window with borders and title bar.
        windowed: ModeState,
        // A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
        // borderless: Monitor,
        // An exclusive fullscreen window that takes over the entire screen of the given monitor.
        // fullscreen: Monitor,
    };

    /// Parameters for creation a new window.
    pub const InitParams = struct {
        /// The mode in which to create the window.
        mode: Mode,
        /// Title of the window.
        title: []const u8,
        /// Width of the window in pixels, only used for windowed and borderless modes.
        width: u32,
        /// Height of the window in pixels, only used for windowed and borderless modes.
        height: u32,
    };
    const Platform = switch (builtin.os.tag) {
        .windows => @import("win32/window_state.zig").WindowStateWin32,
        else => @compileError("Platform not 'yet' supported"),
    };

    platform: Platform,
    full: Rect(i32),
    content: Rect(i32),
    should_close: bool,

    pub fn init(gpa: Allocator, ctx: *WindowSystem, params: InitParams) !WindowState {
        var platform: Platform = try .init(gpa, ctx, params);
        return .{
            .platform = platform,
            .
        };
    }
};
