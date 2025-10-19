const core = @import("core");

const WindowHandles = core.HandleSet(Window);

var windows: WindowHandles = .empty;

pub fn init() !void {}
pub fn deinit() void {}

const Window = struct {
    title: []const u8,
};

pub const WindowHandle = struct {
    handle: WindowHandles.Handle,

    pub fn init() !WindowHandle {}

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
