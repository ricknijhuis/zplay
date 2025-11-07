const root = @import("root");

/// Size of the Win32 raw input buffer, defaults to 16
pub const win32_raw_input_buffer_size = if (@hasDecl(root, "win32_raw_input_buffer_size")) root.win32_raw_input_buffer_size else 16;

/// Count of different keyboard devices that are supported, defaults to 1
pub const keyboard_filter_size = if (@hasDecl(root, "keyboard_filter_size")) root.keyboard_filter_size else 2;

/// Size of the input device queue, defaults to keyboard_filter_size
pub const input_device_queue_size = if (@hasDecl(root, "input_device_queue_size")) root.input_device_queue_size else keyboard_filter_size;

/// Allows for multiple input devices of the same type to be used simultaneously, defaults to false
pub const multi_input_device_support: bool = if (@hasDecl(root, "multi_input_device_support")) root.multi_input_device_support else false;
