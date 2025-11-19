const std = @import("std");
const core = @import("core");
const opt = @import("options");
const debug = std.debug;
const testing = std.testing;

const Key = @import("keys.zig").Key;

const KeyboardSystem = @import("keyboard_system.zig").KeyboardSystem;
const EnumArray = std.EnumArray;

/// Internal representation of the keyboard state.
pub fn KeyboardState(comptime multi_device: bool) type {
    return struct {
        const Self = @This();
        pub const Id = core.Id(Self);

        state: EnumArray(Key, KeyState),
        filter_buffer: if (multi_device) [opt.keyboard_filter_size]Id else void,
        filter_count: if (multi_device) u32 else void,

        pub fn init() Self {
            return .{
                .state = .initFill(.up),
                .filter_buffer = if (multi_device) undefined else {},
                .filter_count = if (multi_device) 0 else {},
            };
        }

        pub fn reset(self: *Self) void {
            // This loop will be vectorized by the compiler in ReleaseFast mode. Though using @Vector here and not modifying the existing values
            // but reassinging seems to emit smaller machine code. Benchmark both ways before changing this.
            for (self.state.values[0..]) |*state| {
                state.reset();
            }
        }

        /// Process a key event
        pub fn process(self: *Self, key: Key, down: bool) void {
            self.state.getPtr(key).update(down);
        }

        /// Process a key event, filtering by keyboard id
        pub fn processFiltered(self: *Self, keyboard: Id, key: Key, down: bool) void {
            comptime debug.assert(multi_device);

            if (self.filter_count == 0) {
                self.state.getPtr(key).update(down);
            } else {
                for (self.filter_buffer[0..self.filter_count]) |id| {
                    if (id == .none or id == keyboard) {
                        self.state.getPtr(key).update(down);
                    }
                }
            }
        }

        /// Adds a device id to the filter, from now on only input comming from devices in the filter will be processed.
        /// The Id is linked to an actual hardware device.
        /// Asserts whether handle is valid
        pub fn filter(self: *Self, id: Id) void {
            debug.assert(self.filter_count < self.filter_buffer.len);
            self.filter_buffer[self.filter_count] = id;
            self.filter_count += 1;
        }

        /// Returns the list of current devices that are filtered.
        /// Asserts whether handle is valid
        pub fn filters(self: *const Self) []const Id {
            return self.filter_buffer[0..self.filter_count];
        }

        /// Returns true if the specified key is currently held down
        pub fn isKeyDown(self: *const Self, key: Key) bool {
            return self.state.get(key).down;
        }

        /// Returns true if the specified key is currently up
        pub fn isKeyUp(self: *const Self, key: Key) bool {
            return !self.state.get(key).down;
        }

        /// Returns true if the specified key was pressed this frame
        pub fn isKeyPressed(self: *const Self, key: Key) bool {
            const state = self.state.get(key);
            return state.down and state.transitioned;
        }

        /// Returns true if the specified key was released this frame
        pub fn isKeyReleased(self: *const Self, key: Key) bool {
            const state = self.state.get(key);
            return !state.down and state.transitioned;
        }
    };
}

/// Represents the last known state of a key, mainly used internally.
pub const KeyState = packed struct(u8) {
    /// If set the key is currently held down
    down: bool,
    /// If set the key state has changed at least once during the frame
    /// This allows to detect key presses and releases
    transitioned: bool,
    _: u6 = 0,

    /// The default 'up' state of a key.
    pub const up: KeyState = .{
        .down = false,
        .transitioned = false,
    };

    /// Resets the transitioned state of the key.
    pub fn reset(self: *KeyState) void {
        self.transitioned = false;
    }

    /// Updates the key state based on whether it is currently down or up.
    /// using the previous state to determine if a transition has occurred.
    pub fn update(self: *KeyState, down: bool) void {
        if (down) {
            if (!self.down) {
                self.down = true;
                self.transitioned = true;
            }
        } else {
            if (self.down) {
                self.down = false;
                self.transitioned = true;
            }
        }
    }
};

test "Keyboard single device: correct state is set when key went down" {
    var keyboard: KeyboardState(false) = .init();

    // Keys are up by default
    try testing.expect(keyboard.isKeyUp(.a));

    // Frame 1
    {
        // Simulate key down
        keyboard.reset();
        keyboard.process(.a, true);

        try testing.expect(keyboard.isKeyPressed(.a));
        try testing.expect(keyboard.isKeyDown(.a));
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 2
    {
        keyboard.reset();

        // Simulate key still down
        keyboard.process(.a, true);

        // As the key is still down, isKeyPressed should be false now
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(keyboard.isKeyDown(.a));
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 3
    {
        keyboard.reset();

        // Simulate key up
        keyboard.process(.a, false);
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(!keyboard.isKeyDown(.a));
        try testing.expect(keyboard.isKeyReleased(.a));
        try testing.expect(keyboard.isKeyUp(.a));
    }
    // Frame 4
    {
        keyboard.reset();

        // Simulate key up
        keyboard.process(.a, false);
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(!keyboard.isKeyDown(.a));
        // As the key was already up, isKeyReleased should be false now
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(keyboard.isKeyUp(.a));
    }
}

test "Keyboard multi device: filters are set correctly" {
    var keyboard: KeyboardState(true) = .init();

    try testing.expectEqual(0, keyboard.filter_count);
    try testing.expectEqual(0, keyboard.filters().len);

    keyboard.filter(@enumFromInt(1));

    try testing.expectEqual(1, keyboard.filter_count);
    try testing.expectEqual(1, keyboard.filters().len);
    try testing.expectEqual(@as(KeyboardState(true).Id, @enumFromInt(1)), keyboard.filters()[0]);
}

test "Keyboard multi device: correct state is set when key went down and filter is set" {
    var keyboard: KeyboardState(true) = .init();

    // Keys are up by default
    try testing.expect(keyboard.isKeyUp(.a));

    keyboard.filter(@enumFromInt(1));

    // Frame 1
    {
        // Simulate key down
        keyboard.reset();

        // This event is from a different keyboard, should be ignored
        keyboard.processFiltered(@enumFromInt(2), .a, true);
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(!keyboard.isKeyDown(.a));
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(keyboard.isKeyUp(.a));

        // This event is from the correct keyboard, should be processed
        keyboard.processFiltered(@enumFromInt(1), .a, true);
        try testing.expect(keyboard.isKeyPressed(.a));
        try testing.expect(keyboard.isKeyDown(.a));
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 2
    {
        keyboard.reset();

        // Simulate key still down
        keyboard.process(.a, true);

        // As the key is still down, isKeyPressed should be false now
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(keyboard.isKeyDown(.a));
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(!keyboard.isKeyUp(.a));
    }
    // Frame 3
    {
        keyboard.reset();

        // Simulate key up
        keyboard.process(.a, false);
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(!keyboard.isKeyDown(.a));
        try testing.expect(keyboard.isKeyReleased(.a));
        try testing.expect(keyboard.isKeyUp(.a));
    }
    // Frame 4
    {
        keyboard.reset();

        // Simulate key up
        keyboard.process(.a, false);
        try testing.expect(!keyboard.isKeyPressed(.a));
        try testing.expect(!keyboard.isKeyDown(.a));
        // As the key was already up, isKeyReleased should be false now
        try testing.expect(!keyboard.isKeyReleased(.a));
        try testing.expect(keyboard.isKeyUp(.a));
    }
}
