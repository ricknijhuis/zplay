const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const meta = core.meta;
const debug = std.debug;

const KeyboardHandle = @import("KeyboardHandle.zig");

const Events = @This();

pub const Devices = struct {
    keyboards: []const KeyboardHandle,
};

const Native = switch (builtin.os.tag) {
    .windows => @import("Win32Events.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

native: Native,

pub fn init() Events {
    const native: Native = .{};
    return Events{
        .native = native,
    };
}

/// Polls events for the windows and given devices.
/// If no devices are given, only window events are processed.
pub fn poll(self: *const Events, devices: anytype) !void {
    const T = @TypeOf(devices);
    const info = @typeInfo(T);

    comptime debug.assert(info == .@"struct");
    comptime debug.assert(info.@"struct".is_tuple);

    try self.native.pollEvents(devices);
}
