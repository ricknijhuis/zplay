const std = @import("std");
const zp = @import("zplay");

pub fn main() !void {
    try zp.app.init(.{});
    defer zp.app.deinit();

    const window = try zp.window.create(.{
        .mode = .{
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });

    while (!window.shouldClose()) {
        try zp.event.poll();
    }
}
