const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const app = @import("app.zig");
const asserts = core.asserts;

const Allocator = std.mem.Allocator;
const App = app.App;
const HandleSet = core.HandleSet;
const String = core.StringTable.String;
const Rect = core.Rect;

/// Internal representation of a window.
pub const Internal = struct {
    pub const Impl = switch (builtin.os.tag) {
        .windows => @import("win32/Window.zig"),
        else => @compileError("Platform not 'yet' supported"),
    };
    pub const Id = core.Id(Internal);
    impl: Impl,
    id: Id,
    title: String,
    full: Rect(i32),
    content: Rect(i32),
    should_close: bool,
};

/// A handle to a window.
pub const Window = struct {
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
    pub const CreateParams = struct {
        /// The mode in which to create the window.
        mode: Mode,
        /// Title of the window.
        title: []const u8,
        /// Width of the window in pixels, only used for windowed and borderless modes.
        width: u32,
        /// Height of the window in pixels, only used for windowed and borderless modes.
        height: u32,
    };
    const HandleT = HandleSet(Internal).Handle;

    const instance = &app.Internal.instance;

    handle: HandleT,

    /// Creates a new window with the specified parameters.
    /// Returns a handle to the created window.
    /// It will not be visible until `show()` is called, unless the mode is fullscreen.
    /// It will not be focused until `focus()` is called, unless the mode is fullscreen.
    /// Asserts that it is called on the main thread.
    pub fn create(gpa: Allocator, params: CreateParams) !Window {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const handle = try instance.windows.addOneExact(gpa);
        var self = instance.windows.getPtr(handle);
        self.should_close = false;
        self.title = try instance.strings.getOrPut(gpa, params.title);
        self.full = .init(0, 0, @intCast(params.width), @intCast(params.height));

        try Internal.Impl.create(self, handle, gpa);

        self.full = Internal.Impl.fullRect(self);
        self.content = Internal.Impl.contentRect(self);
        self.id = .generate();
        return .{ .handle = handle };
    }

    /// Destroys the specified window and releases its resources.
    /// Asserts that it is called on the main thread.
    pub fn destroy(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.destroy(self);
        instance.windows.swapRemove(window.handle);
    }

    /// Returns the currently focused window.
    /// This can be used in combination with input functions to determine which window is receiving input.
    pub fn focused() Window {
        return .{ .handle = app.Internal.instance.focused };
    }

    /// Hides the specified window.
    /// Asserts that it is called on the main thread.
    pub fn hide(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.hide(self);
    }

    /// Shows the specified window.
    /// Asserts that it is called on the main thread.
    pub fn show(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.show(self);
    }

    /// Maximizes the specified window.
    /// Asserts that it is called on the main thread.
    pub fn maximize(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.maximize(self);
    }

    /// Restores the specified window from a minimized or maximized state.
    /// Asserts that it is called on the main thread.
    pub fn restore(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.restore(self);
    }

    /// Minimizes the specified window.
    /// Asserts that it is called on the main thread.
    pub fn minimize(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.minimize(self);
    }

    /// Resizes the specified window to the given width and height.
    /// Asserts that it is called on the main thread.
    pub fn resize(window: Window, width: u32, height: u32) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.resize(self, width, height);
    }

    /// Decorates the specified window with borders and title bar.
    /// Asserts that it is called on the main thread.
    pub fn decorate(window: Window) !void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        try Internal.Impl.decorate(self);
    }

    /// Focuses the specified window, bringing it to the foreground.
    /// Asserts that it is called on the main thread.
    pub fn focus(window: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread_id);

        const self = instance.windows.getPtr(window.handle);
        Internal.Impl.focus(self);
    }

    /// Returns true if the specified window should close.
    /// Can be called from any thread but access is not synchronized.
    pub fn shouldClose(window: Window) bool {
        return instance.windows.getPtr(window.handle).should_close;
    }
};
