const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const app = @import("app.zig");
const opt = @import("options.zig");
const kbd = @import("keyboard.zig");

const RingBuffer = core.RingBuffer;

// Flags for various events that occurred during event polling, used to trigger further actions.
// Usage of these flags prevent the need from calling functions that can fail inside the platform specific event polling implementation like wndProc on win32.
pub const EventFlags = packed struct(u8) {
    /// Indicates that the set of connected monitors has changed.
    /// Call Monitor.poll to update the monitor list.
    monitors_changed: bool = false,
    /// Indicates that the set of connected input devices has changed.
    input_devices_changed: bool = false,
    _: u6 = 0,
};

pub const Internal = struct {
    pub const Impl = switch (builtin.os.tag) {
        .windows => @import("win32/Platform.zig"),
        else => @compileError("Platform not 'yet' supported"),
    };
    pub const InputDeviceId = union(enum) {
        keyboard: kbd.Internal.Id,
        // Will add mice, gamepads, etc. later
    };
    const instance = &app.Internal.instance;

    impl: Impl,
    event_flags: EventFlags,
    event_device_queue: RingBuffer(InputDeviceId, opt.input_device_queue_size),
    keyboard_map: [512]kbd.Keyboard.Key,
    scancode_map: [512]kbd.Keyboard.Key,

    pub fn init() !void {
        try Impl.init(&instance.platform);
        instance.platform.event_device_queue = .empty;
    }

    pub fn deinit() void {
        Impl.deinit(&app.Internal.instance.platform);
    }

    pub fn pushInputDevice(device: InputDeviceId) void {
        const last = instance.event_device_queue.peek();
        if (last) |existing_id| {
            if (std.meta.eql(device, existing_id)) {
                // Duplicate event, ignore
                return;
            }
        } else {
            instance.event_device_queue.push(device);
        }
    }
};

pub const Platform = struct {
    const instance = &app.Internal.instance;

    pub fn pollEvents() !void {
        Internal.Impl.pollEvents(&instance.platform);
    }
};

fn enumIndex(value: anytype) u32 {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    inline for (info.@"enum".fields, 0..) |field, index| {
        if (field.name == @tagName(value)) {
            return @as(u32, index);
        }
    }
}
test "scancode to keycode" {
    const scancode: kbd.Internal.Impl.Scancde = .a;

    const index = enumIndex(scancode);
    try std.testing.expect(index == 31);
}
