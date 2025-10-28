const std = @import("std");
const builtin = @import("builtin");
const Events = @This();
const KeyboardHandle = @import("KeyboardHandle.zig");

const debug = std.debug;

pub const Devices = struct {
    keyboards: []const KeyboardHandle,
};

const Native = switch (builtin.os.tag) {
    .windows => @import("Win32Events.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

native: Native,

pub fn init() !Events {
    const native: Native = .{};
    return Events{
        .native = native,
    };
}

/// Polls events for the windows and given devices.
pub fn poll(self: *const Events, devices: anytype) !void {
    const T = @TypeOf(devices);
    const info = @typeInfo(T);

    debug.assert(info == .@"struct");
    debug.assert(info.@"struct".is_tuple);

    const keyboards = fieldsOfType(KeyboardHandle, devices);

    std.log.info("{any}", .{keyboards});

    try self.native.pollEvents();
}

fn fieldsOfType(comptime T: type, value: anytype) [fieldCount(T, value)]T {
    const ti = @typeInfo(@TypeOf(value));
    switch (ti) {
        .@"struct" => |s| {
            // Count matching fields
            comptime var count: usize = 0;
            inline for (s.fields) |f| {
                if (f.type == T) count += 1;
            }

            // Build a fixed-size array of matching fields
            var arr: [count]T = undefined;
            inline for (s.fields, 0..) |f, i| {
                if (f.type == T) {
                    arr[i] = @field(value, f.name);
                }
            }
            return arr[0..];
        },
        else => @compileError("Expected a tuple or struct"),
    }
}

fn fieldCount(comptime T: type, value: anytype) usize {
    const ti = @typeInfo(@TypeOf(value));
    switch (ti) {
        .@"struct" => |s| {
            // Count matching fields
            comptime var count: usize = 0;
            inline for (s.fields) |f| {
                if (f.type == T) count += 1;
            }
            return count;
        },
        else => @compileError("Expected a tuple or struct"),
    }
}
