const std = @import("std");
const pl = @import("platform");
const gpa = @import("gpa.zig");
const str = @import("strings.zig");
const wnd = @import("window.zig");
const mntr = @import("monitor.zig");
const evnt = @import("event.zig");
const opt = @import("options.zig");
const kbd = @import("keyboard.zig");

const Thread = std.Thread;

pub const Internal = struct {
    pub var instance: Internal = undefined;

    main_thread: Thread.Id,
};

pub const App = struct {
    /// Parameters for initializing the global context.
    pub const InitParams = struct {
        allocator: ?std.mem.Allocator = null,
    };

    pub fn init(params: InitParams) !void {
        Internal.instance = .{
            .main_thread = Thread.getCurrentId(),
        };

        try gpa.Internal.init(params.allocator);
        try str.Internal.init();
        try evnt.Internal.init();
        try mntr.Internal.init();
        try wnd.Internal.init();

        pl.callbacks.onClose = onCloseCallback;
        pl.callbacks.onDisplayChange = onDisplayChangeCallback;
        pl.callbacks.onKeyboardEvent = onKeyboardEventCallback;
    }

    pub fn deinit() void {
        wnd.Internal.deinit();
        mntr.Internal.deinit();
        kbd.Internal.deinit();
        evnt.Internal.deinit();
        str.Internal.deinit();
        gpa.Internal.deinit();
    }

    pub fn allocator() std.mem.Allocator {
        return gpa.Internal.instance;
    }
};

pub fn onCloseCallback(window: pl.Window) void {
    const handle: wnd.Window = .{ .value = .fromInt(window.getUserData(u32)) };
    const ptr = wnd.Internal.getPtr(handle);
    ptr.should_close = true;
}

pub fn onDisplayChangeCallback() void {
    // TODO: Handle error?
    mntr.Internal.poll() catch {};
}

pub fn onKeyboardEventCallback(keyboard: pl.Keyboard, scancode: pl.Keyboard.Scancode, down: bool) void {
    kbd.Internal.process(keyboard, scancode, down);

    if (comptime opt.multi_input_device_support) {
        // TODO: Handle error?
        evnt.Internal.pushEventDevice(.{ .keyboard = kbd.Keyboard.Id.fromInt(keyboard.getId()) });
    }
}
