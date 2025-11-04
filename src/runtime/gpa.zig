const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const app = @import("app.zig");
const debug = std.debug;
const asserts = core.asserts;

pub const Internal = struct {
    pub var instance: std.mem.Allocator = undefined;
    var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}){} else void{};

    pub fn init(allocator: ?std.mem.Allocator) !void {
        asserts.isOnThread(app.Internal.instance.main_thread);
        if (allocator) |gpa| {
            instance = gpa;
        } else if (builtin.mode == .Debug) {
            instance = debug_allocator.allocator();
        } else {
            instance = std.heap.smp_allocator;
        }
    }

    pub fn deinit() void {
        if (builtin.mode == .Debug) {
            const check = debug_allocator.deinit();
            debug.assert(check == .ok);
        }
    }
};
