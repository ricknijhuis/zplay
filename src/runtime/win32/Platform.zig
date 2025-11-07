const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;
const opt = @import("../options.zig");
const pl = @import("../platform.zig");
const kbd = @import("../keyboard.zig");
const debug = std.debug;
const errors = core.errors;
const meta = core.meta;

const KeyboardKey = kbd.Keyboard.Key;
const Alignment = std.mem.Alignment;

const Win32Platform = @This();

const raw_input_buffer_size = opt.win32_raw_input_buffer_size * @sizeOf(c.RAWINPUT) / @sizeOf(usize);

instance: c.HINSTANCE,
focused: c.HWND,
raw_input_buffer: [raw_input_buffer_size]usize,
keycodes_map: [@intFromEnum(Scancode.last) + 1]KeyboardKey,
scancodes_map: [@intFromEnum(KeyboardKey.last) + 1]Scancode,
main_window_class: ?u16,
child_window_class: ?u16,
is_paused_pressed: bool,

pub fn init(self: *pl.Internal) !void {
    self.impl.instance = errors.panicIfNull(c.GetModuleHandleW(null), "Unable to get HINSTANCE");
    self.impl.main_window_class = null;
    self.impl.child_window_class = null;
    self.impl.raw_input_buffer = undefined;
    self.impl.is_paused_pressed = false;

    var dev: c.RAWINPUTDEVICE = std.mem.zeroes(c.RAWINPUTDEVICE);
    dev.usUsagePage = 1;
    dev.usUsage = 6; // Keyboard
    dev.dwFlags = .{
        .EXCLUDE = 1,
        .PAGEONLY = 1,
        .DEVNOTIFY = 1,
    }; // No legacy messages, only raw input
    dev.hwndTarget = null;

    try errors.throwIfZero(
        c.RegisterRawInputDevices(@ptrCast(&dev), 1, @sizeOf(c.RAWINPUTDEVICE)),
        error.FailedToInitialize,
        "Failed to register win32 raw input device",
    );

    const scancodes = @typeInfo(Scancode).@"enum".fields;
    const keycodes = @typeInfo(KeyboardKey).@"enum".fields;

    inline for (scancodes, keycodes) |scancode, keycode| {
        self.impl.keycodes_map[scancode.value] = @enumFromInt(keycode.value);
        self.impl.scancodes_map[keycode.value] = @enumFromInt(scancode.value);
    }
}

pub fn deinit(self: *pl.Internal) void {
    self.event_flags = .{};
    self.impl.is_paused_pressed = false;
    self.impl.main_window_class = null;
    self.impl.child_window_class = null;

    var dev: c.RAWINPUTDEVICE = std.mem.zeroes(c.RAWINPUTDEVICE);
    dev.usUsagePage = 1;
    dev.usUsage = 6; // Keyboard
    dev.dwFlags = .{
        .REMOVE = 1,
    };
    dev.hwndTarget = null;

    _ = c.RegisterRawInputDevices(@ptrCast(&dev), 1, @sizeOf(c.RAWINPUTDEVICE));
}

pub fn pollEvents(self: *pl.Internal) void {
    processRawInput(self);

    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        _ = c.TranslateMessage(&msg);
        _ = c.DispatchMessageW(&msg);
    }
}

fn processRawInput(self: *pl.Internal) void {
    kbd.Internal.reset();

    var size: u32 = self.impl.raw_input_buffer.len;
    var count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, self.impl.raw_input_buffer[0..]), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));

    // Depening on the size of our buffer we might need to call GetRawInputBuffer multiple times to process all available input
    // If performance becomes an issue we can increase the buffer size or process input in a different way.
    // Increase buffer size in opt.win32_raw_input_buffer_size
    while (count != 0) {
        if (count == -1) {
            return;
        }

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            var input = std.mem.bytesAsValue(c.RAWINPUT, self.impl.raw_input_buffer[i * size ..]);

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
                if (self.impl.is_paused_pressed) {
                    if (scancode == 0x45) {
                        scancode = 0xE11D45;
                    }
                    self.impl.is_paused_pressed = false;
                } else if (scancode == 0xE11D) {
                    self.impl.is_paused_pressed = true;
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

                // Convert raw or partially prefixed scancode to encoded value
                const code: Scancode = Scancode.encode(scancode);
                const key: KeyboardKey = self.impl.keycodes_map[@intFromEnum(code)];

                // Process the key event, possibly filtering by device
                if (comptime opt.multi_input_device_support) {
                    const id: pl.Internal.InputDeviceId = .{ .keyboard = @enumFromInt(input.header.hDevice) };
                    kbd.Internal.processFiltered(id, key, down);
                    pl.Internal.pushInputDevice(id);
                } else {
                    kbd.Internal.process(key, down);
                }
            }
            input = nextRawInputBlock(input);
        }

        count = c.GetRawInputBuffer(std.mem.bytesAsValue(c.RAWINPUT, self.impl.raw_input_buffer[0..]), &size, @intCast(@sizeOf(c.RAWINPUTHEADER)));
    }
}

// Replacement for the win32 API macro NEXTRAWINPUTBLOCK
fn nextRawInputBlock(ptr: *c.RAWINPUT) *c.RAWINPUT {
    const next = @intFromPtr(ptr) + ptr.header.dwSize;
    const aligned = Alignment.of(usize).forward(next);
    return @ptrFromInt(aligned);
}

/// A encoded version of the win32 scancode set. the encoding allows for all to be represented within 512 values keeping memory usage low.
pub const Scancode = enum(u32) {
    escape = 0x01,
    @"1" = 0x02,
    @"2" = 0x03,
    @"3" = 0x04,
    @"4" = 0x05,
    @"5" = 0x06,
    @"6" = 0x07,
    @"7" = 0x08,
    @"8" = 0x09,
    @"9" = 0x0A,
    @"0" = 0x0B,
    minus = 0x0C,
    equals = 0x0D,
    backspace = 0x0E,
    tab = 0x0F,
    q = 0x10,
    w = 0x11,
    e = 0x12,
    r = 0x13,
    t = 0x14,
    y = 0x15,
    u = 0x16,
    i = 0x17,
    o = 0x18,
    p = 0x19,
    bracket_left = 0x1A,
    bracket_right = 0x1B,
    enter = 0x1C,
    control_left = 0x1D,
    a = 0x1E,
    s = 0x1F,
    d = 0x20,
    f = 0x21,
    g = 0x22,
    h = 0x23,
    j = 0x24,
    k = 0x25,
    l = 0x26,
    semicolon = 0x27,
    apostrophe = 0x28,
    grave = 0x29,
    shift_left = 0x2A,
    backslash = 0x2B,
    z = 0x2C,
    x = 0x2D,
    c = 0x2E,
    v = 0x2F,
    b = 0x30,
    n = 0x31,
    m = 0x32,
    comma = 0x33,
    period = 0x34,
    slash = 0x35,
    shift_right = 0x36,
    numpad_multiply = 0x37,
    alt_left = 0x38,
    space = 0x39,
    caps_lock = 0x3A,
    f1 = 0x3B,
    f2 = 0x3C,
    f3 = 0x3D,
    f4 = 0x3E,
    f5 = 0x3F,
    f6 = 0x40,
    f7 = 0x41,
    f8 = 0x42,
    f9 = 0x43,
    f10 = 0x44,
    num_lock = 0x45,
    scroll_lock = 0x46,
    numpad_7 = 0x47,
    numpad_8 = 0x48,
    numpad_9 = 0x49,
    numpad_minus = 0x4A,
    numpad_4 = 0x4B,
    numpad_5 = 0x4C,
    numpad_6 = 0x4D,
    numpad_plus = 0x4E,
    numpad_1 = 0x4F,
    numpad_2 = 0x50,
    numpad_3 = 0x51,
    numpad_0 = 0x52,
    numpad_period = 0x53,
    alt_print_screen = 0x54,
    bracket_angle = 0x56,
    f11 = 0x57,
    f12 = 0x58,
    oem_1 = 0x5a,
    oem_2 = 0x5b,
    oem_3 = 0x5c,
    erase_eof = 0x5d,
    oem_4 = 0x5e,
    oem_5 = 0x5f,
    zoom = 0x62,
    help = 0x63,
    f13 = 0x64,
    f14 = 0x65,
    f15 = 0x66,
    f16 = 0x67,
    f17 = 0x68,
    f18 = 0x69,
    f19 = 0x6a,
    f20 = 0x6b,
    f21 = 0x6c,
    f22 = 0x6d,
    f23 = 0x6e,
    oem_6 = 0x6f,
    katakana = 0x70,
    oem_7 = 0x71,
    f24 = 0x76,
    sbcschar = 0x77,
    convert = 0x79,
    nonconvert = 0x7B,

    media_previous = 0x110,
    media_next = 0x119,
    numpad_enter = 0x11C,
    control_right = 0x11D,
    volume_mute = 0x120,
    launch_app2 = 0x121,
    media_play = 0x122,
    media_stop = 0x124,
    volume_down = 0x12E,
    volume_up = 0x130,
    browser_home = 0x132,
    numpad_divide = 0x135,
    print_screen = 0x137,
    alt_right = 0x138,
    cancel = 0x146,
    home = 0x147,
    arrow_up = 0x148,
    page_up = 0x149,
    arrow_left = 0x14B,
    arrow_right = 0x14D,
    end = 0x14F,
    arrow_down = 0x150,
    page_down = 0x151,
    insert = 0x152,
    delete = 0x153,
    meta_left = 0x15B,
    meta_right = 0x15C,
    application = 0x15D,
    power = 0x15E,
    sleep = 0x15F,
    wake = 0x163,
    browser_search = 0x165,
    browser_favorites = 0x166,
    browser_refresh = 0x167,
    browser_stop = 0x168,
    browser_forward = 0x169,
    browser_back = 0x16A,
    launch_app1 = 0x16B,
    launch_email = 0x16C,
    launch_media = 0x16D,
    pause = 0x145,

    pub const last = meta.enums.greatest(Scancode);

    /// Decodes the given encoded scancode back to the original win32 scancode.
    pub fn decode(encoded: Scancode) u32 {
        return switch (@intFromEnum(encoded)) {
            0x145 => 0xE11D45, // Pause/Break
            else => if (encoded & 0x100 != 0)
                0xE000 | (encoded & 0xFF)
            else
                encoded & 0xFF,
        };
    }

    /// Encodes the given raw win32 scancode into the compressed Scancode representation.
    fn encode(raw: u32) Scancode {
        // Pause/Break — unique E1-prefixed sequence
        if (raw == 0xE11D45)
            return @enumFromInt(0x145);

        // E0-prefixed extended keys (Right Ctrl, Print Screen, arrows, etc.)
        if ((raw & 0xFF00) == 0xE000)
            return @enumFromInt(0x100 | (raw & 0xFF));

        // Normal key
        return @enumFromInt(raw & 0xFF);
    }
};
