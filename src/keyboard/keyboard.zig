const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const opt = @import("options");
const keys = @import("keys.zig");

const KeyboardSystem = @import("keyboard_system.zig").KeyboardSystem;
const KeyboardState = @import("keyboard_state.zig").KeyboardState;
const Allocator = std.mem.Allocator;
const HandleSet = core.HandleSet;

fn KeyboardImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return KeyboardMultipleDevices;
    } else {
        return KeyboardSingleDevice;
    }
}

fn SharedKeyboardImpl(comptime Self: type) type {
    return struct {
        pub const Key = keys.Key;

        const instance = KeyboardSystem.get();

        /// Returns true if the specified key is currently held down
        pub fn isKeyDown(self: Self, key: Key) bool {
            const keyboard = instance.keyboards.getPtr(self.handle);
            return keyboard.state.get(key).down;
        }

        /// Returns true if the specified key is currently up
        pub fn isKeyUp(self: Self, key: Key) bool {
            const keyboard = instance.keyboards.getPtr(self.handle);
            return !keyboard.state.get(key).down;
        }

        /// Returns true if the specified key was pressed this frame
        pub fn isKeyPressed(self: Self, key: Key) bool {
            const keyboard = instance.keyboards.getPtr(self.handle);
            const state = keyboard.state.get(key);
            return state.down and state.transitioned;
        }

        /// Returns true if the specified key was released this frame
        pub fn isKeyReleased(self: Self, key: Key) bool {
            const keyboard = instance.keyboards.getPtr(self.handle);
            const state = keyboard.state.get(key);
            return !state.down and state.transitioned;
        }

        pub fn getKeyName(key: Key, buffer: []u8) []const u8 {
            return KeyboardSystem.getKeyName(key, buffer);
        }
    };
}

/// Keyboard handle that supports multiple keyboard input devices.
/// Because it needs to filter input from multiple devices, it has a slightly higher overhead than a single device implementation
const KeyboardMultipleDevices = struct {
    pub const Key = keys.Key;

    const instance = KeyboardSystem.get();

    const HandleT = core.HandleSet(KeyboardState).Handle;

    handle: HandleT,

    /// Initializes a new keyboard instance, returns a handle to it.
    /// All keys are initialized to the 'up' state.
    /// After this call the keyboard will receive input as soon as platform.pollEvents is called.
    pub fn init(gpa: Allocator) !KeyboardMultipleDevices {
        const handle = try instance.keyboards.addOne(gpa);
        const keyboard = instance.keyboards.getPtr(handle);

        keyboard.state = .initFill(.up);
        keyboard.filter_count = 0;
        keyboard.filter_buffer = undefined;

        return .{ .handle = handle };
    }

    pub fn deinit(self: KeyboardMultipleDevices) void {
        instance.keyboards.swapRemove(self.handle);
    }

    pub const isKeyDown = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyDown;
    pub const isKeyUp = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyUp;
    pub const isKeyPressed = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyPressed;
    pub const isKeyReleased = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyReleased;
    pub const getKeyName = SharedKeyboardImpl(KeyboardMultipleDevices).getKeyName;
};

/// Keyboard handle that does not support device filtering, All keyboard input from all devices will be processed withoug ability to filter.
/// Because it does not need to filter it has a lower overhead than a multiple device implementation in both memory and performance.
const KeyboardSingleDevice = struct {
    pub const Key = Key;
    const instance = KeyboardSystem.get();

    const HandleT = core.HandleSet(KeyboardState).Handle;

    handle: HandleT,

    /// Initializes a new keyboard instance, returns a handle to it.
    /// All keys are initialized to the 'up' state.
    /// After this call the keyboard will receive input as soon as platform.pollEvents is called.
    pub fn init(gpa: Allocator) !KeyboardSingleDevice {
        const handle = try instance.keyboards.addOne(gpa);
        const keyboard = instance.keyboards.getPtr(handle);

        keyboard.state = .initFill(.up);

        return .{ .handle = handle };
    }

    pub fn deinit(self: KeyboardSingleDevice) void {
        instance.keyboards.swapRemove(self.handle);
    }

    pub const isKeyDown = SharedKeyboardImpl(KeyboardSingleDevice).isKeyDown;
    pub const isKeyUp = SharedKeyboardImpl(KeyboardSingleDevice).isKeyUp;
    pub const isKeyPressed = SharedKeyboardImpl(KeyboardSingleDevice).isKeyPressed;
    pub const isKeyReleased = SharedKeyboardImpl(KeyboardSingleDevice).isKeyReleased;
    pub const getKeyName = SharedKeyboardImpl(KeyboardSingleDevice).getKeyName;
};

/// Kyboard handle type, either single or multiple device support based on comptime configuration
/// Set options.keyboard_multi_input_device_support to true to enable multiple device support
pub const Keyboard = KeyboardImpl(opt.enable_keyboard_multiple_devices);

test "Keyboard: correct state is set when key went down" {
    const gpa = std.testing.allocator;

    const instance = KeyboardSystem.get();
    instance.keyboards = .empty;
    instance.platform = undefined;
    defer instance.keyboards.deinit(gpa);

    const keyboard: KeyboardImpl(false) = try .init(gpa);

    // Keys are up by default
    try std.testing.expect(keyboard.isKeyUp(.a));

    // Frame 1
    {
        // Simulate key down
        instance.reset();
        instance.process(.a, true);

        try std.testing.expect(keyboard.isKeyPressed(.a));
        try std.testing.expect(keyboard.isKeyDown(.a));
        try std.testing.expect(!keyboard.isKeyReleased(.a));
        try std.testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 2
    {
        instance.reset();

        // Simulate key still down
        instance.process(.a, true);
        // As the key is still down, isKeyPressed should be false now
        try std.testing.expect(!keyboard.isKeyPressed(.a));
        try std.testing.expect(keyboard.isKeyDown(.a));
        try std.testing.expect(!keyboard.isKeyReleased(.a));
        try std.testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 3
    {
        instance.reset();

        // Simulate key up
        instance.process(.a, false);
        try std.testing.expect(!keyboard.isKeyPressed(.a));
        try std.testing.expect(!keyboard.isKeyDown(.a));
        try std.testing.expect(keyboard.isKeyReleased(.a));
        try std.testing.expect(keyboard.isKeyUp(.a));
    }
    // Frame 4
    {
        instance.reset();

        // Simulate key up
        instance.process(.a, false);
        try std.testing.expect(!keyboard.isKeyPressed(.a));
        try std.testing.expect(!keyboard.isKeyDown(.a));
        // As the key was already up, isKeyReleased should be false now
        try std.testing.expect(!keyboard.isKeyReleased(.a));
        try std.testing.expect(keyboard.isKeyUp(.a));
    }
}

test "Keyboard: getKeyName returns scancode name" {
    if (builtin.os.tag != .windows) return;

    const instance = KeyboardSystem.get();
    instance.keyboards = .empty;
    instance.platform = undefined;
    instance.platform.initKeyMaps();

    var buffer: [16:0]u8 = undefined;
    const name = Keyboard.getKeyName(.a, &buffer);
    try std.testing.expectEqualStrings(name, "A");
}
