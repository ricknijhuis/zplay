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
    asserts.isError(err);

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
pub fn reduce(comptime err: anytype, val: anytype) @TypeOf(err)!@typeInfo(@TypeOf(val)).error_union.payload {
    return val catch return err;
}

const TestError = error{ TestError1, TestError2 };
// Only able to test happy paths for now as panics would fail the test and error logs will
// make the test step fail
test "throwIfNotTrue: happy path" {
    try throwIfNotTrue(true, TestError.TestError1, "should not fail");
}

test "panicIfNotTrue: happy path" {
    panicIfNotTrue(true, "should not panic");
}

test "throwIfZero: happy path" {
    try throwIfZero(42, TestError.TestError1, "should not fail");
}

test "panicIfZero: happy path" {
    panicIfZero(1, "should not panic");
}

test "throwIfNull: happy path" {
    const maybe_val: ?u8 = 7;
    const val = try throwIfNull(maybe_val, TestError.TestError1, "should not fail");
    try std.testing.expectEqual(@as(u8, 7), val);
}

test "panicIfNull: happy path" {
    const maybe_val: ?u8 = 99;
    const val = panicIfNull(maybe_val, "should not panic");
    try std.testing.expectEqual(@as(u8, 99), val);
}

test "throwIfError: happy path" {
    const ok_value: TestError!u8 = 10;
    const val = throwIfError(ok_value, "should succeed");
    try std.testing.expectEqual(@as(u8, 10), val);
}

test "panicIfError: happy path" {
    const ok_value: TestError!u8 = 77;
    const val = panicIfError(ok_value, "should not panic");
    try std.testing.expectEqual(@as(u8, 77), val);
}

test "reduce: happy path" {
    const UnifiedError = error{Unified};

    const ok_val: TestError!u8 = 42;
    const val = try reduce(UnifiedError.Unified, ok_val);
    try std.testing.expectEqual(@as(u8, 42), val);
}
