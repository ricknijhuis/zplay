//! This module provides some asserts used by zplay.
//! As with the standard library, though these asserts may be optimized out in release builds though
//! that is not guaranteed, for example when the conditions have side effects.

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

/// Asserts at comptime that the given value is of integer type.
/// This works for unsigned, signed, and comptime integers.
pub inline fn isInt(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .int or @typeInfo(@TypeOf(value)) == .comptime_int);
}

/// Asserts at comptime that the given value is of optional type.
pub inline fn isOptional(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .optional);
}

/// Asserts at comptime that the given value is of error union type.
pub inline fn isErrorUnion(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .error_union);
}

/// Asserts at comptime that the given value is of error set type.
pub inline fn isError(value: anytype) void {
    comptime debug.assert(@typeInfo(@TypeOf(value)) == .error_set);
}
