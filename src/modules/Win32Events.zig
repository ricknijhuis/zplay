const std = @import("std");
const c = @import("win32").everything;
const context = @import("context.zig");

const ArrayListAligned = std.ArrayListAligned;

const Win32Events = @This();

const instance = &context.instance;

var buffer: ArrayListAligned(u8, .@"8") = .empty;

pub fn pollEvents(self: Win32Events) !void {
    try self.processRawInput();

    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        switch (msg.message) {
            else => {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageW(&msg);
            },
        }
    }
}

fn processRawInput(self: Win32Events) !void {
    _ = self;
    var size: u32 = 0;
    var count = c.GetRawInputBuffer(null, &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));
    if (count == -1 or count != 0 or size == 0) {
        return;
    }

    // Support up to 16 raw input events at once
    // Maybe make it configurable later
    size *= 16;

    try buffer.resize(instance.gpa, size);

    count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, buffer.items), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));

    if (count == -1) {
        return;
    }

    std.log.info("INPUT COUNT: {d}", .{count});

    // const input: *c.RAWINPUT = @ptrCast([0]);
}
