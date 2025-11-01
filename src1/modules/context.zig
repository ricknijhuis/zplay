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
const Keyboard = @import("Keyboard.zig");
const Events = @import("Events.zig");

const Context = struct {
    gpa: Allocator,
    strings: StringTable,
    main_thread: Thread.Id,
    windows: HandleSet(Window),
    monitors: HandleSet(Monitor),
    keyboards: HandleSet(Keyboard),
    events: Events,
};

pub var instance: Context = .{
    .gpa = undefined,
    .main_thread = undefined,
    .strings = .empty,
    .windows = .empty,
    .monitors = .empty,
    .keyboards = .empty,
    .events = .empty,
};

pub const events = struct {
    pub fn poll(devices: anytype) !void {
        for (instance.keyboards.items) |keyboard| {
            keyboard.state = .initFill(.down);
        }
        try instance.events.poll(devices);
    }
};

pub const keyboard = struct {};

pub const window = struct {
    pub fn create(config: W)
};
