const std = @import("std");
const c = @import("win32").everything;
const context = @import("context.zig");
const core = @import("core");
const meta = core.meta;
const debug = std.debug;

const KeyboardHandle = @import("KeyboardHandle.zig");
const Win32Keyboard = @import("Win32Keyboard.zig");
const Scancode = Win32Keyboard.Scancode;
const Key = KeyboardHandle.Key;
const ArrayListAligned = std.ArrayListAligned;
const Alignment = std.mem.Alignment;

const Win32Events = @This();

const instance = &context.instance;

var buffer: ArrayListAligned(u8, .@"8") = .empty;
var is_paused_pressed: bool = false;

pub fn pollEvents(self: Win32Events, devices: anytype) !void {
    try self.processRawInput(devices);

    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        switch (msg.message) {
            else => {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageW(&msg);
            },
        }
    }
}

fn processRawInput(self: Win32Events, devices: anytype) !void {
    _ = self;

    const keyboards: [meta.fieldCountOfType(KeyboardHandle, @TypeOf(devices))]KeyboardHandle = undefined;
    keyboards = meta.fieldsOfType(KeyboardHandle, devices, keyboards);

    var size: u32 = 0;
    var count = c.GetRawInputBuffer(null, &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));
    if (count == -1 or count != 0 or size == 0) {
        return;
    }

    // Support up to 16 raw input events at once
    // Maybe make it configurable later
    size *= 16;

    try buffer.resize(instance.gpa, size);

    count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, buffer.items), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));

    if (count == -1) {
        return;
    }

    var input: *c.RAWINPUT = std.mem.bytesAsValue(c.RAWINPUT, buffer.items);

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        if (input.header.dwType == @as(u32, @intFromEnum(c.RIM_TYPEKEYBOARD))) {
            var state: Key.State = .up;
            var scancode: u32 = input.data.keyboard.MakeCode;
            const flags = input.data.keyboard.Flags;
            debug.assert(scancode <= 0xff);

            if ((flags & c.RI_KEY_BREAK) == 0) {
                state = .down;
            }

            if ((flags & c.RI_KEY_E0) != 0) {
                scancode |= 0xE000;
            } else if ((flags & c.RI_KEY_E1) != 0) {
                scancode |= 0xE100;
            }
            if (is_paused_pressed) {
                if (scancode == 0x45) {
                    scancode = 0xE11D45;
                }
                is_paused_pressed = false;
            } else if (scancode == 0xE11D) {
                is_paused_pressed = true;
            } else if (scancode == 0x54) {
                // Alt + print screen return scancode 0x54 but we want it to return 0xE037 because 0x54 will not return a name for the key.
                scancode = 0xE037;
            }
            // Some scancodes we can ignore:
            // - 0xE11D: first part of the Pause scancode (handled above);
            // - 0xE02A: first part of the Print Screen scancode if no Shift, Control or Alt keys are pressed;
            // - 0xE02A, 0xE0AA, 0xE036, 0xE0B6: generated in addition of Insert, Delete, Home, End, Page Up, Page Down, Up, Down, Left, Right when num lock is on; or when num lock is off but one or both shift keys are pressed;
            // - 0xE02A, 0xE0AA, 0xE036, 0xE0B6: generated in addition of Numpad Divide and one or both Shift keys are pressed;
            // - Some of those a break scancode;

            // When holding a key down, the pre/postfix (0xE02A) is not repeated.

            if (scancode == 0xE11D or scancode == 0xE02A or scancode == 0xE0AA or scancode == 0xE0B6 or scancode == 0xE036) {
                continue;
            }

            const code: Scancode = @enumFromInt(scancode);
            const key: Key = Win32Keyboard.map.get(code);

            for (keyboards) |keyboard_handle| {
                const keyboard = instance.keyboards.getPtr(keyboard_handle);
                if (keyboard.native.handle) |handle| {
                    if (handle != input.header.hDevice) {
                        continue;
                    }
                    keyboard.state.set(key, state);
                }
            }

            input = nextRawInputBlock(input);
        }
    }
}

// Replacement for the win32 API macro NEXTRAWINPUTBLOCK
fn nextRawInputBlock(ptr: *c.RAWINPUT) *c.RAWINPUT {
    const next = @intFromPtr(ptr) + ptr.header.dwSize;
    const aligned = Alignment.of(usize).forward(next);
    return @ptrFromInt(aligned);
}
