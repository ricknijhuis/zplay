pub const KeyboardSystem = @import("keyboard_system.zig").KeyboardSystem;
pub const KeyboardState = @import("keyboard_state.zig").KeyboardState;
// pub const Keyboard = @import("keyboard.zig").Keyboard;

test {
    _ = KeyboardSystem;
    _ = KeyboardState;
    // _ = Keyboard;
    _ = @import("win32/keyboard_system.zig");
}
