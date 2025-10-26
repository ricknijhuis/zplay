const std = @import("std");
const zp = @import("zplay");

const Window = zp.WindowHandle;
const Monitor = zp.MonitorHandle;
const Events = zp.Events;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const monitor: Monitor = try .primary();
    const window: Window = try .init(.{
        .mode = .{
            .fullscreen = monitor,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    const events: Events = try .init();

    while (!window.shouldClose()) {
        events.poll();
    }
}
