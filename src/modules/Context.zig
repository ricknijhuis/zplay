const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const debug = std.debug;

const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator(.{});
const StringTable = core.StringTable;
const Thread = std.Thread;

// pub var gpa: Allocator = undefined;
// pub var strings: StringTable = .empty;

const Context = struct {
    gpa: Allocator,
    strings: StringTable,
    main_thread_id: Thread.Id,
};

pub var instance: Context = .{
    .gpa = undefined,
    .strings = .empty,
    .main_thread_id = undefined,
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

    instance.main_thread_id = Thread.getCurrentId();
}

pub fn deinit() void {
    instance.strings.deinit(instance.gpa);

    if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    }
}
