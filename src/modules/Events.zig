const Events = @This();

const Win32Events = @import("Win32Events.zig");

const Native = union(enum) {
    win32: Win32Events,
};

native: Native,

pub fn init() !Events {
    const native: Native = blk: {
        comptime if (@import("builtin").os.tag == .windows) {
            break :blk .{ .win32 = Win32Events{} };
        };

        return error.UnsupportedPlatform;
    };

    return Events{
        .native = native,
    };
}
pub fn poll(self: *const Events) void {
    switch (self.native) {
        inline else => |*platform| {
            platform.pollEvents();
        },
    }
}
