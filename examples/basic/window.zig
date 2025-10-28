const std = @import("std");
const zp = @import("zplay");

const Window = zp.WindowHandle;
const Events = zp.Events;
const Keyboard = zp.KeyboardHandle;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const keyboard: Keyboard = try .init();
    const window: Window = try .init(.{
        .mode = .{
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    const events: Events = try .init();

    while (!window.shouldClose()) {
        try events.poll(.{keyboard});
        std.Thread.sleep(10000000);
    }
}
