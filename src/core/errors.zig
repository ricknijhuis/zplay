//! This module provides utility functions for error handling with logging.
//! Internal code should prefer using these functions to ensure consistent logging behavior.
//! These functions log error messages before returning errors or panicking.
//! The user can specify custom logging behavior and panic handling by overriding the default
//! logging and panic functions in `std.options`.
const std = @import("std");
const asserts = @import("asserts.zig");

const debug = std.debug;

/// If the given condition is not true, logs the given message and returns the given error.
pub fn throwIfNotTrue(condition: bool, err: anytype, msg: []const u8) @TypeOf(err)!void {
    asserts.IsError(err);

    if (condition)
        return;

    std.log.err("{s}", .{msg});
    return err;
}

/// If the given condition is not true, logs the given message and panics.
pub fn panicIfNotTrue(condition: bool, msg: []const u8) void {
    if (condition)
        return;

    std.log.err("{s}", .{msg});
    @panic(msg);
}

/// If the given condition is zero, logs the given message and returns the given error.
pub fn throwIfZero(condition: anytype, err: anytype, msg: []const u8) @TypeOf(err)!void {
    asserts.isInt(condition);
    asserts.isError(err);

    if (condition != 0)
        return;

    std.log.err("{s}", .{msg});
    return err;
}

/// If the given condition is zero, logs the given message and panics.
pub fn panicIfZero(condition: anytype, msg: []const u8) void {
    asserts.isInt(condition);

    if (condition != 0)
        return;

    std.log.err("{s}", .{msg});
    @panic(msg);
}

/// If the given optional value is null, logs the given message and returns the given error. else returns the unwrapped value.
pub fn throwIfNull(value: anytype, err: anytype, msg: []const u8) @TypeOf(err)!@typeInfo(@TypeOf(value)).optional.child {
    asserts.isOptional(value);
    asserts.isError(err);

    if (value) |val| {
        return val;
    }

    std.log.err("{s}", .{msg});
    return err;
}

/// If the given optional value is null, logs the given message and panics. else returns the unwrapped value.
pub fn panicIfNull(value: anytype, msg: []const u8) @typeInfo(@TypeOf(value)).optional.child {
    asserts.isOptional(value);

    if (value) |val| {
        return val;
    }

    std.log.err("{s}", .{msg});
    @panic(msg);
}
/// If the given error union value is an error, logs the given message and returns the error. else returns the unwrapped value.
/// Basically the same as `try` but with logging.
pub fn throwIfError(value: anytype, msg: []const u8) @TypeOf(value) {
    asserts.isErrorUnion(value);

    const result = value catch |err| {
        std.log.err("{any}, msg: {s}", .{ err, msg });
        return err;
    };
    return result;
}

/// If the given error union value is an error, logs the given message and panics. else returns the unwrapped value.
pub fn panicIfError(value: anytype, msg: []const u8) @typeInfo(@TypeOf(value)).error_union.payload {
    asserts.isErrorUnion(value);

    const result = value catch |err| {
        std.log.err("{any}, msg: {s}", .{ err, msg });
        @panic(msg);
    };

    return result;
}

/// Logs the given message and returns the given error.
/// Should either be used in combination with try, catch or return.
/// Should be used instead of directly returning the error to ensure consistent logging.
pub fn throw(err: anytype, msg: []const u8) @TypeOf(err)!void {
    asserts.isError(err);

    std.log.err("{s}", .{msg});
    return err;
}

/// Reduces the given error union value to a unified error type by mapping any error to the given UnifiedError.
pub fn reduce(comptime UnifiedError: anyerror, val: anytype) !@typeInfo(@TypeOf(val)).ErrorUnion.payload {
    return val catch return UnifiedError;
}
