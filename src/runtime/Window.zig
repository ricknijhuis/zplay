const std = @import("std");
const core = @import("core");
const pl = @import("platform");
const gpa = @import("gpa.zig");
const app = @import("app.zig");
const mntr = @import("monitor.zig");
const str = @import("strings.zig");

const asserts = core.asserts;

const Monitor = mntr.Monitor;
const String = core.StringTable.String;
const HandleSet = core.HandleSet;

/// For internal use. Is not exposed through root.zig
pub const Internal = struct {
    var instance: HandleSet(Internal) = undefined;

    native: pl.Window,
    title: String,
    width: u32,
    height: u32,
    should_close: bool,

    pub fn init() !void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        instance = .empty;
    }
    pub fn deinit() void {
        for (instance.items) |*window| {
            window.native.destroy();
        }
        instance.deinit(gpa.Internal.instance);
    }

    pub fn getPtr(handle: Window) *Internal {
        return instance.getPtr(handle.value);
    }
};

/// Represents a handle to a window.
pub const Window = struct {
    /// Includes Monitor.QueryMonitorError because creating a window in borderless or fullscreen mode
    /// requires querying monitor information, which may fail.
    pub const CreateWindowError = error{
        NativeWindowCreationFailed,
    }; // || Monitor.QueryMonitorError;

    pub const Error = std.mem.Allocator.Error || CreateWindowError;

    pub const ModeType = enum {
        /// A standard window with borders and title bar using the given size.
        windowed,
        /// A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
        borderless,
        /// An exclusive fullscreen window that takes over the entire screen of the given monitor.
        fullscreen,
    };

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

    pub const Mode = union(ModeType) {
        /// A standard window with borders and title bar.
        windowed: ModeState,
        /// A borderless window that covers the entire screen but is not in exclusive fullscreen mode.
        borderless: Monitor,
        /// An exclusive fullscreen window that takes over the entire screen of the given monitor.
        fullscreen: Monitor,
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

    const HandleT = HandleSet(Internal).Handle;

    /// The actual handle value
    value: HandleT,

    /// Creates a new window with the given initialization parameters.
    /// Asserts is on main thread
    pub fn create(params: InitParams) !Window {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const handle = try Internal.instance.addOneExact(gpa.Internal.instance);
        var self = Internal.instance.getPtr(handle);

        self.native = try .create(gpa.Internal.instance, params.title);
        self.native.setUserData(handle.toInt());

        switch (params.mode) {
            .windowed => |state| {
                switch (state) {
                    .normal => {
                        self.native.resize(params.width, params.height);
                        self.native.show();
                        self.native.focus();
                    },
                    .minimized => {
                        self.native.resize(params.width, params.height);
                        self.native.minimize();
                    },
                    .maximized => {
                        self.native.resize(params.width, params.height);
                        self.native.maximize();
                        self.native.show();
                        self.native.focus();
                    },
                    .hidden => {
                        self.native.resize(params.width, params.height);
                        self.native.hide();
                    },
                }
            },
            .borderless, .fullscreen => |monitor_handle| {
                const monitor = mntr.Internal.instance.getPtr(monitor_handle.value);

                try switch (params.mode) {
                    .borderless => self.native.borderless(&monitor.native),
                    .fullscreen => self.native.fullscreen(&monitor.native),
                    else => {},
                };

                self.native.show();
                self.native.focus();
            },
        }

        self.title = try str.Internal.instance.getOrPut(gpa.Internal.instance, params.title);
        self.width = params.width;
        self.height = params.height;
        self.should_close = false;

        return .{ .value = handle };
    }

    /// Destroys the natve window associated with the given handle
    /// Asserts is on main thread
    /// Asserts whether handle is valid
    pub fn destroy(handle: *Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        var self = Internal.instance.getPtr(handle.value);
        self.native.destroy();

        Internal.instance.swapRemove(handle.value);

        handle.value = .none;
    }

    /// Returns true if the window has been requested to close.
    /// Asserts whether handle is valid
    pub fn shouldClose(self: Window) bool {
        return Internal.instance.getPtr(self.value).should_close;
    }

    /// Returns the size of the window as a Vec2u32 (width, height).
    /// Asserts whether handle is valid
    pub fn getSize(self: Window) core.Vec2u32 {
        const window = Internal.instance.getPtr(self.value);
        return .init(window.width, window.height);
    }

    /// Resizes the given window to new width and height
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn resize(self: Window, size: core.Vec2u32) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.resize(size.x(), size.y());
    }

    /// Maximizes the window to fill the screen, without going into fullscreen mode.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn maximize(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.maximize();
    }

    /// Restores the window to its previous size and position before being maximized or minimized.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn restore(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.restore();
    }

    /// Minimizes the window to the taskbar or dock.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn minimize(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.minimize();
    }

    /// Hides the window from view.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn hide(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.hide();
    }

    /// Shows the window if it is hidden.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn show(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.show();
    }

    /// Brings the window to the foreground and gives it focus.
    /// Asserts is on main thread
    /// Asserts handle is valid
    pub fn focus(self: Window) void {
        asserts.isOnThread(app.Internal.instance.main_thread);

        const window = Internal.instance.getPtr(self.value);
        window.native.focus();
    }

    /// Returns whether the handle points to an active window resource or not
    pub fn isValid(self: Window) bool {
        return Internal.instance.contains(self.value);
    }
};
