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

const Context = struct {
    gpa: Allocator,
    strings: StringTable,
    main_thread: Thread.Id,
    // windows: HandleSet(Window),
    // monitors: HandleSet(Monitor),
    // keyboards: HandleSet(Keyboard),
    // events: Events,
};

var debug_allocator: DebugAllocator = .{};

pub var instance: Context = .{
    .gpa = undefined,
    .main_thread = undefined,
    .strings = .empty,
    .windows = .empty,
    .monitors = .empty,
    .keyboards = .empty,
    .events = .empty,
};

// Namespaces operate on the global context, handles operate on created resources in the global context.
pub const app = struct {
    pub fn init() !void {}
    pub fn deinit() !void {}
};

pub const window = struct {
    pub fn create() !void {}
    pub fn destroy() void {}
};

pub const keyboard = struct {
    pub fn init() !void {}
    pub fn deinit() void {}
};

pub const monitor = struct {
    pub fn primary() !void {}
    pub fn closest() !void {}
};

pub const event = struct {
    pub fn poll() !void {}
};
