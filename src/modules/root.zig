const std = @import("std");
const Windowing = @import("windowing/root.zig");

pub var gpa: std.mem.Allocator = undefined;

pub const WindowHandle = Windowing.WindowHandle;

pub fn init(allocator: ?std.mem.Allocator) !void {
    if (allocator) |alloc| {
        gpa = alloc;
    } else {
        gpa = std.heap.smp_allocator;
    }

    try Windowing.init();
}

pub fn deinit() void {
    Windowing.deinit();
}
