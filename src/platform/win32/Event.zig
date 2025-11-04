const std = @import("std");
const core = @import("core");
const pl = @import("../root.zig");
const options = @import("../options.zig");
const c = @import("win32").everything;
const debug = std.debug;
const errors = core.errors;

const Keyboard = @import("Keyboard.zig");
const Alignment = std.mem.Alignment;

const Event = @This();

buffer: [options.win32_raw_input_buffer_size * @sizeOf(c.RAWINPUT) / @sizeOf(usize)]usize align(std.mem.Alignment.of(usize).toByteUnits()),
is_paused_pressed: bool,

pub fn init() !Event {
    var dev: c.RAWINPUTDEVICE = std.mem.zeroes(c.RAWINPUTDEVICE);
    dev.usUsagePage = 1;
    dev.usUsage = 6; // Keyboard
    dev.dwFlags = .{
        .EXCLUDE = 1,
        .PAGEONLY = 1,
        .DEVNOTIFY = 1,
    };
    dev.hwndTarget = null;

    try errors.throwIfZero(
        c.RegisterRawInputDevices(@ptrCast(&dev), 1, @sizeOf(c.RAWINPUTDEVICE)),
        error.FailedToInitialize,
        "Failed to register win32 raw input device",
    );

    return Event{
        .buffer = undefined,
        .is_paused_pressed = false,
    };
}

pub fn deinit(self: *Event) void {
    self.buffer = undefined;
    self.is_paused_pressed = false;

    var dev: c.RAWINPUTDEVICE = std.mem.zeroes(c.RAWINPUTDEVICE);
    dev.usUsagePage = 1;
    dev.usUsage = 6; // Keyboard
    dev.dwFlags = .{
        .REMOVE = 1,
    };
    dev.hwndTarget = null;

    _ = c.RegisterRawInputDevices(@ptrCast(&dev), 1, @sizeOf(c.RAWINPUTDEVICE));
}

pub fn poll(self: *Event) !void {
    self.processRawInput();

    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        _ = c.TranslateMessage(&msg);
        _ = c.DispatchMessageW(&msg);
    }
}

fn processRawInput(self: *Event) void {
    var size: u32 = self.buffer.len;
    var count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, self.buffer[0..]), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));
    while (count != 0) {
        if (count == -1) {
            return;
        }

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            var input = std.mem.bytesAsValue(c.RAWINPUT, self.buffer[i * size ..]);
            // Process input here

            if (input.header.dwType == @as(u32, @intFromEnum(c.RIM_TYPEKEYBOARD))) {
                var down: bool = false;
                var scancode: u32 = input.data.keyboard.MakeCode;
                const flags = input.data.keyboard.Flags;
                debug.assert(scancode <= 0xff);

                if ((flags & c.RI_KEY_BREAK) == 0) {
                    down = true;
                }

                if ((flags & c.RI_KEY_E0) != 0) {
                    scancode |= 0xE000;
                } else if ((flags & c.RI_KEY_E1) != 0) {
                    scancode |= 0xE100;
                }
                if (self.is_paused_pressed) {
                    if (scancode == 0x45) {
                        scancode = 0xE11D45;
                    }
                    self.is_paused_pressed = false;
                } else if (scancode == 0xE11D) {
                    self.is_paused_pressed = true;
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

                const code: Keyboard.Scancode = @enumFromInt(scancode);

                // TODO: Safe to unwrap here?
                pl.callbacks.onKeyboardEvent(.{ .handle = input.header.hDevice.? }, code, down);
            }
            input = nextRawInputBlock(input);
        }

        count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, self.buffer[0..]), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));
    }
}

// Replacement for the win32 API macro NEXTRAWINPUTBLOCK
fn nextRawInputBlock(ptr: *c.RAWINPUT) *c.RAWINPUT {
    const next = @intFromPtr(ptr) + ptr.header.dwSize;
    const aligned = Alignment.of(usize).forward(next);
    return @ptrFromInt(aligned);
}
