//! This module defines the global context for the application, managing resources such as
//! memory allocation, string tables, and handle sets for windows and monitors and other resources.
//! There should only be one instance of this context throughout the application lifecycle.
//! Generally users should not need to interact with this module directly, as it is used internally by other modules.
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
}

pub fn deinit() void {
    instance.windows.deinit(instance.gpa);
    instance.monitors.deinit(instance.gpa);
    instance.strings.deinit(instance.gpa);

    if (builtin.mode == .Debug) {
        // TODO: check for memory leaks
        _ = debug_allocator.deinit();
    }
}

pub fn get() *Context {
    return &instance;
}
