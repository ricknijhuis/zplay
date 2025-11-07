const std = @import("std");
const core = @import("core");
const wnd = @import("window.zig");
const mntr = @import("monitor.zig");
const pl = @import("platform.zig");
const kb = @import("keyboard.zig");
const asserts = core.asserts;

const Allocator = std.mem.Allocator;
const HandleSet = core.HandleSet;
const StringTable = core.StringTable;
const Thread = std.Thread;

pub const Internal = struct {
    pub var instance: Internal = undefined;

    main_thread_id: Thread.Id,
    strings: StringTable,
    platform: pl.Internal,
    focused: HandleSet(wnd.Internal).Handle,
    windows: HandleSet(wnd.Internal),
    monitors: HandleSet(mntr.Internal),
    keyboards: HandleSet(kb.Internal),
    // display_modes: HandleSet(mntr.DisplayMode),
};

pub const App = struct {
    pub fn init(gpa: Allocator) !void {
        Internal.instance.main_thread_id = Thread.getCurrentId();
        Internal.instance.strings = .empty;
        Internal.instance.windows = .empty;
        Internal.instance.monitors = .empty;
        Internal.instance.focused = .none;

        try pl.Internal.init();

        try mntr.Monitor.poll(gpa);
    }
    pub fn deinit(gpa: Allocator) void {
        asserts.isOnThread(Internal.instance.main_thread_id);

        for (Internal.instance.windows.items) |*window| {
            wnd.Internal.Impl.destroy(window);
        }

        pl.Internal.deinit();

        Internal.instance.keyboards.deinit(gpa);
        Internal.instance.windows.deinit(gpa);
        Internal.instance.monitors.deinit(gpa);
        Internal.instance.strings.deinit(gpa);
    }
};
