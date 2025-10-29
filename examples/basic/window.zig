const std = @import("std");
const zp = @import("zplay");

const Window = zp.WindowHandle;
const Events = zp.Events;
const Keyboard = zp.KeyboardHandle;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const keyboard: Keyboard = try zp.keyboard.init();
    const window: Window = try zp.window.init(.{
        .mode = .{
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });

    while (!window.shouldClose()) {
        try zp.events.poll(.{keyboard});

        if (keyboard.getKeyState(.w) == .down) {
            std.debug.print("W key is pressed\n", .{});
        }
    }
}
