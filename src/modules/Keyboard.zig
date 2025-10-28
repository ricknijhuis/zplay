const std = @import("std");
const builtin = @import("builtin");
const EnumArray = std.EnumArray;

const KeyboardHandle = @import("KeyboardHandle.zig");

native: Native,
state: EnumArray(KeyboardHandle.Key, KeyboardHandle.Key.State),

pub const Native = switch (builtin.os.tag) {
    .windows => @import("Win32Keyboard.zig"),
    else => @compileError("Platform not 'yet' supported"),
};
