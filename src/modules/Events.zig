const builtin = @import("builtin");
const Events = @This();

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

pub fn poll(self: *const Events) !void {
    try self.native.pollEvents();
}
