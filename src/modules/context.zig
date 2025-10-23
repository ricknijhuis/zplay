const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const debug = std.debug;

const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator(.{});
const StringTable = core.StringTable;
const Thread = std.Thread;
const HandleSet = core.HandleSet;

const Window = @import("Window.zig");
const Monitor = @import("Monitor.zig");

// TODO: Maybe move all handle collections to here as well, as they need to be deinitialized from here as well.
const Context = struct {
    gpa: Allocator,
    strings: StringTable,
    main_thread: Thread.Id,
    windows: HandleSet(Window),
    monitors: HandleSet(Monitor),
};

pub var instance: Context = .{
    .gpa = undefined,
    .main_thread = undefined,
    .strings = .empty,
    .windows = .empty,
    .monitors = .empty,
};

var debug_allocator: DebugAllocator = .{};

pub fn init(allocator: ?Allocator) !void {
    if (allocator) |alloc| {
        instance.gpa = alloc;
    } else if (builtin.mode == .Debug) {
        instance.gpa = debug_allocator.allocator();
    } else {
        instance.gpa = std.heap.smp_allocator;
    }

    instance.main_thread = Thread.getCurrentId();
    std.log.info("VAL: {any}", .{instance.main_thread});
}

pub fn deinit() void {
    instance.windows.deinit(instance.gpa);
    instance.monitors.deinit(instance.gpa);
    instance.strings.deinit(instance.gpa);

    if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    }
}

pub fn get() *Context {
    return &instance;
}
