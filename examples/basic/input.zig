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

    // Create a window, will be destroyed automatically on app deinit. If you want to destroy it earlier, call window.destroy()
    const window: zp.Window = try .create(.{
        .mode = .{
            // Create a normal windowed mode window with borders and title bar
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });

    // Create a keyboard device to receive keyboard events, once initialized Event.poll() will start sending events to it
    const keyboard: zp.Keyboard = try .init();

    // Checks for window close event in a loop, generally best to do this on your 'main' window.
    while (!window.shouldClose()) {
        // Polls for events for registered devices. Currently only window events are handled. See input.zig for input device event handling.
        try zp.Event.poll();

        // Check if the last reported state of the given key is down
        if (keyboard.isKeyDown(.escape)) {
            // Destroys the native window, resulting in corresponding shouldClose flag to be set to true.
            window.destroy();
        }

        try io.sleep(.fromMilliseconds(10), .cpu_thread);
    }
}
