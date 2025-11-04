const std = @import("std");
const zp = @import("zplay");

// This example requires you to have 2 keyboards connected. It will listen until it has recieved input from 2 different devices,
// once received it will asign a device to each player. From then you are able to process input per player. this will work the same for mice, and gamepads
pub fn main() !void {
    try zp.App.init(.{});
    defer zp.App.deinit();

    const window: zp.Window = try .create(.{
        .mode = .{
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });

    var player1_device_id: zp.Keyboard.Id = .none;
    var player2_device_id: zp.Keyboard.Id = .none;

    std.log.info("Please press a key on a keyboard for Player 1...", .{});
    std.log.info("Please press a key on a different keyboard for Player 2...", .{});

    while (!window.shouldClose() and (player1_device_id == .none or player2_device_id == .none)) {
        try zp.Event.poll();

        // getEventDevice returns all unique devices used in order.
        while (zp.Event.getEventDevice()) |id| {
            // std.log.info("Device with ID: {any} was used", .{id});

            switch (id) {
                // getEventDevice returns union of possible devices, we are only interested in keyboards for now
                .keyboard => |kbd_id| {
                    if (player1_device_id == .none) {
                        player1_device_id = kbd_id;
                    } else if (player2_device_id == .none and player1_device_id != kbd_id) {
                        player2_device_id = kbd_id;
                    }
                },
                else => {},
            }
        }
    }

    if (window.shouldClose()) return;

    const player1: zp.Keyboard = try .init();
    player1.filter(player1_device_id);

    const player2: zp.Keyboard = try .init();
    player2.filter(player2_device_id);

    while (!window.shouldClose()) {
        // Reset the keyboard state
        player1.reset();
        player2.reset();

        // Poll the events and fill the keyboard state. The keyboards will only recieve events belonging to their device filter
        try zp.Event.poll();

        // Key is pressed down for player one
        if (player1.isKeyDown(.w)) {
            std.log.info("Player 1 pressed W", .{});
        }

        // Key is pressed down for player two
        if (player2.isKeyDown(.w)) {
            std.log.info("Player 2 pressed W", .{});
        }
    }
}

// To enable multiple devices define this comptime variable in your root file (where fn main is defined)
// Defaults to false
pub const multi_input_device_support = true;
// This specifies the cound to different devices per device type that are allowed. if for example you would expect 4 players with different keyboards/gamepads. put it on 4.
// Defaults to 2
// pub const keyboard_filter_size = 2;

// This specifies the count of different items that fit in the queue that we poll with getEventDevice. if more devices are detected it will override the oldest record
// Defaults to keyboard_filter_size
// pub const input_device_queue_size = keyboard_filter_size;
