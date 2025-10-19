const builtin = @import("builtin");
const core = @import("core");
const mods = @import("../root.zig");

const Win32Window = @import("Win32Window.zig");
const WindowHandles = core.HandleSet(Window);

var windows: WindowHandles = .empty;

pub fn init() !void {}
pub fn deinit() void {}

const Window = struct {
    handle: NativeWindow,
    title: []const u8,
};

const NativeWindow = union(enum) {
    win32: Win32Window,
};

pub const WindowHandle = struct {
    pub const Mode = enum {
        fullscreen,
        borderless,
        windowed,
    };

    pub const InitParams = struct {
        mode: Mode,
        title: []const u8,
    };

    handle: WindowHandles.Handle,

    pub fn init(params: InitParams) !WindowHandle {
        const handle: NativeWindow = blk: {
            comptime if (builtin.os.tag == .windows) {
                break :blk .{ .win32 = try .init() };
            };
        };

        const window = try windows.addOneExact(mods.gpa, .{
            .handle = handle,
            .title = "zplay",
        });

        return window;
    }

    pub fn deinit(self: WindowHandle) void {
        _ = self; // autofix
    }
    pub fn shouldClose(self: WindowHandle) bool {
        _ = self; // autofix
    }
    pub fn getSize(self: WindowHandle) core.Vec2u32 {
        _ = self; // autofix
    }
    pub fn setSize(self: WindowHandle, size: core.Vec2u32) void {
        _ = self; // autofix
        _ = size; // autofix
    }
    pub fn maximize(self: WindowHandle) void {
        _ = self; // autofix
    }
    pub fn minimize(self: WindowHandle) void {
        _ = self; // autofix
    }
};
