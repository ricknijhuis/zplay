const std = @import("std");
const zp = @import("zplay");

const Monitor = zp.MonitorHandle;
const Window = zp.WindowHandle;
const Events = zp.Events;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const monitor: Monitor = try .primary();
    std.log.info("Primary monitor name: {s}", .{monitor.getName()});
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
        events.poll();
    }
}
