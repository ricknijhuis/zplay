const root = @import("root");

pub const keyboard_support = if (@hasDecl(root, "keyboard_support")) root.keyboard_support else true;
pub const mouse_support = if (@hasDecl(root, "mouse_support")) root.mouse_support else true;

pub const win32_raw_input_buffer_size = if (@hasDecl(root, "win32_raw_input_buffer_size")) root.win32_raw_input_buffer_size else 16;
