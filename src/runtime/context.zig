//! This module defines the global context for the application, managing resources such as
//! memory allocation, string tables, and handle sets for windows and monitors and other resources.
//! There should only be one instance of this context throughout the application lifecycle.
//! Generally users should not need to interact with this module directly, as it is used internally by other modules.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const pl = @import("platform");
const options = @import("options.zig");
const mem = std.mem;
const debug = std.debug;

const Allocator = mem.Allocator;
const EnumArray = std.EnumArray;
const Deque = std.Deque;
const StringTable = core.StringTable;
const String = StringTable.String;
const Thread = std.Thread;
const HandleSet = core.HandleSet;
const KeyboardHandle = @import("KeyboardHandle.zig");

pub const InputDeviceId = union(enum) {
    keyboard: KeyboardId,
    mouse: u64,
    gamepad: u64,
};

const Context = struct {
    gpa: Allocator,
    strings: StringTable,
    main_thread: Thread.Id,
    windows: HandleSet(Window),
    monitors: HandleSet(Monitor),
    keyboards: HandleSet(Keyboard),
    events: Event,
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
