const std = @import("std");
const zp = @import("zplay");

const Io = std.Io;

pub fn main() !void {
    // Initialize the ZPlay application
    // If no allocator is provided, the default allocator will be used (SmpAllocator in release modes or DebugAllocator in debug mode)
    try zp.App.init(.{});
    defer zp.App.deinit();

    const allocator = zp.App.allocator();

    var threaded: Io.Threaded = .init(allocator);
    defer threaded.deinit();

    const io = threaded.io();

    // Our primary window
    const window: zp.Window = try .create(.{
        .mode = .{
            // Create a normal windowed mode window with borders and title bar
            .windowed = .normal,
        },
        .title = "ZPlay Window 1",
        .width = 800,
        .height = 600,
    });

    var window1: zp.Window = try .create(.{
        .mode = .{
            // Create a normal windowed mode window with borders and title bar
            .windowed = .normal,
        },
        .title = "ZPlay Window 2",
        .width = 800,
        .height = 600,
    });

    // Checks for window close event in a loop, generally best to do this on your 'main' window.
    while (!window.shouldClose()) {
        // We allow destroying the second window while still keep the main window open
        // after destroying the window1
        if (window1.isValid() and window1.shouldClose()) {
            window1.destroy();
        }

        // Polls for events for registered devices. Currently only window events are handled. See input.zig for input device event handling.
        try zp.Event.poll();

        try io.sleep(.fromMilliseconds(10), .cpu_thread);
    }
}
