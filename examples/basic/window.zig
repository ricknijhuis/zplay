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

    while (!window.shouldClose()) {
        try zp.events.poll(.{keyboard});

        if (keyboard.getKeyState(.w) == .down) {
            std.debug.print("W key is pressed\n", .{});
        }
    }
}
