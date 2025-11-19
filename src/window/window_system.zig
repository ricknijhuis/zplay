const builtin = @import("builtin");
const core = @import("core");

const WindowState = @import("window_state.zig").WindowState;
const HandleSet = core.HandleSet(WindowState);

pub const WindowSystem = struct {
    const Platform = switch (builtin.os.tag) {
        .windows => @import("win32/window_system.zig").WindowSystemWin32,
        else => @compileError("Platform not 'yet' supported"),
    };

    platform: Platform,
    windows: HandleSet,

    pub fn init() !WindowSystem {
        return .{
            .platform = try .init(),
            .windows = .empty,
        };
    }

    pub fn deinit(self: *WindowSystem) void {
        self.platform.deinit();
        self.windows.deinit();
    }
};
