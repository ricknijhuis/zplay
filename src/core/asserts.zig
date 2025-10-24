const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;

const Thread = std.Thread;

/// Asserts that the current thread is the required thread.
pub inline fn isOnThread(required: Thread.Id) void {
    if (comptime builtin.mode == .Debug) {
        const current = Thread.getCurrentId();
        debug.assert(current == required);
    }
}

/// Asserts that the given value is of integer type.
/// This works for both, unsigned, signed and comptime integers.
pub inline fn isInt(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .int or @typeInfo(@TypeOf(value)) == .comptime_int);
}

/// Asserts that the given value is of optional type.
pub inline fn isOptional(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .optional);
}

/// Asserts that the given value is of error union type.
pub inline fn isErrorUnion(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .error_union);
}
