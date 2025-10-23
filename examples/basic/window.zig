const std = @import("std");
const zp = @import("zplay");

// const Modules = zp.Modules;
// const ModulesConfig = zp.ModulesConfig;

const Monitor = zp.MonitorHandle;
const Window = zp.WindowHandle;
// const Keyboard = zp.KeyboardHandle;
// const Mouse = zp.MouseHandle;
const Events = zp.Events;
// const Controller = zp.Controller;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const monitors = try Monitor.all();

    for (monitors) |handle| {
        std.log.info("{s}", .{handle.getName()});
    }
    const window: Window = try .init(.{
        .mode = .{
            .windowed = .minimized,
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

// pub fn main() !void {
//     try zp.init(null);
//     defer zp.deinit();

//     const window: Window = try .init(.{
//         .mode = .windowed,
//         .title = "ZPlay Window",
//         .width = 800,
//         .height = 600,
//     });
//     defer window.deinit();

//     // stores input state for given window/s
//     const keyboard: Keyboard = try .init(window);
//     defer keyboard.deinit();

//     // stores input state for given window/s
//     const mouse: Mouse = try .init(window);
//     defer mouse.deinit();

//     // stores input state for given window/s
//     const controller: Controller = try .init(window);
//     defer controller.deinit();

//     // Used for processing platform events
//     const events = Events.init();

//     // Add custom event callbacks
//     events.addWindowResizeCallback(resize_callback_fn);
//     events.addWindowCloseCallback(close_callback_fn);
//     events.addKeyboardCallback(keyboard_callback_fn);

//     defer events.deinit();

//     while (!window.shouldClose()) {
//         // Poll and handle events only for given selection
//         if (controller.is_connected) {
//             events.poll(.{ controller, keyboard, mouse, window });
//         } else {
//             events.poll(.{ keyboard, mouse, window });
//         }
//     }
// }
