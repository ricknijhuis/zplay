const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;

const Thread = std.Thread;

pub inline fn isOnThread(required: Thread.Id) void {
    if (comptime builtin.mode == .Debug) {
        const current = Thread.getCurrentId();
        debug.assert(current == required);
    }
}
