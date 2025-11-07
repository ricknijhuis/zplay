const std = @import("std");
const zp = @import("zplay");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    try zp.App.init(gpa);
    defer zp.App.deinit(gpa);

    const window: zp.Window = try .create(gpa, .{
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
        .mode = .{
            .windowed = .normal,
        },
    });

    const keyboard: zp.Keyboard = try .init(gpa);

    window.show();

    while (!window.shouldClose()) {
        try zp.Platform.pollEvents();

        if (keyboard.isKeyPressed(.w)) {
            std.log.info("W key is pressed", .{});
        }
        if (keyboard.isKeyReleased(.w)) {
            std.log.info("W key is released", .{});
        }
        if (keyboard.isKeyDown(.w)) {
            std.log.info("W key is down, count: {any}", .{i});
        }
    }
}
