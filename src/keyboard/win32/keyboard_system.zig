const std = @import("std");
const builtin = @import("builtin");
const c = @import("win32").everything;
const core = @import("core");
const opt = @import("options");
const debug = std.debug;
const testing = std.testing;
const errors = core.errors;
const meta = core.meta;

const KeyboardSystem = @import("../keyboard_system.zig").KeyboardSystem;
const KeyboardState = @import("../keyboard_state.zig").KeyboardState;
const Key = @import("../keys.zig").Key;

pub const KeyboardSystemWin32 = struct {
    keycodes_map: [@intFromEnum(Scancode.last) + 1]Key,
    scancodes_map: [@intFromEnum(Key.last) + 1]Scancode,

    pub fn init() !KeyboardSystemWin32 {
        if (!comptime builtin.is_test) {
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
        }

        const scancodes = @typeInfo(Scancode).@"enum".fields;
        const keycodes = @typeInfo(Key).@"enum".fields;

        var self: KeyboardSystemWin32 = .{
            .keycodes_map = undefined,
            .scancodes_map = undefined,
        };
        
        inline for (scancodes, keycodes) |scancode, keycode| {
            self.keycodes_map[scancode.value] = @enumFromInt(keycode.value);
            self.scancodes_map[keycode.value] = @enumFromInt(scancode.value);
        }

        return self;
    }

    pub fn deinit(self: *KeyboardSystemWin32) void {
        _ = self;
        var dev: c.RAWINPUTDEVICE = std.mem.zeroes(c.RAWINPUTDEVICE);
        dev.usUsagePage = 1;
        dev.usUsage = 6; // Keyboard
        dev.dwFlags = .{
            .REMOVE = 1,
        };
        dev.hwndTarget = null;

        _ = c.RegisterRawInputDevices(@ptrCast(&dev), 1, @sizeOf(c.RAWINPUTDEVICE));
    }

    pub fn process(self: *KeyboardSystemWin32, scancode: u32, down: bool) void {
        const parent: *KeyboardSystem = @alignCast(@fieldParentPtr("platform", self));
        const code: Scancode = Scancode.encode(scancode);
        const key: Key = self.keycodes_map[@intFromEnum(code)];

        parent.process(key, down);
    }

    pub fn processForDevice(self: *KeyboardSystemWin32, id: u32, scancode: u32, down: bool) void {
        const parent: *KeyboardSystem = @alignCast(@fieldParentPtr("platform", self));
        const code: Scancode = Scancode.encode(scancode);
        const key: Key = self.keycodes_map[@intFromEnum(code)];

        parent.processFiltered(@enumFromInt(id), key, down);
    }

    // pub fn getScancodeName(key: Key, name_out: [16:0]u8) []const u8 {}

    pub fn getScancodeName(self: *KeyboardSystemWin32, key: Key, name_out: []u8) []const u8 {
        const scancode = self.scancodes_map[@intFromEnum(key)];
        const full_scancode = Scancode.decode(scancode);
        std.log.err("SCANCODE: {any}, {any}", .{ scancode, full_scancode });

        var lParam: u32 = 0;
        const extended = full_scancode & 0xFFFF00;

        if (extended != 0) {
            if (extended == 0xE11D00) {
                // Pause key special case
                lParam = 0x45 << 16;
            } else {
                // E0-prefixed
                lParam = (0x100 | (full_scancode & 0xFF)) << 16;
            }
        } else {
            lParam = full_scancode << 16;

            // Special handling for NumLock (0x45)
            if (full_scancode == 0x45) {
                lParam |= (0x1 << 24);
            }
        }

        var utf16_buff: [16:0]u16 = undefined;

        var result = c.GetKeyNameTextW(
            @intCast(lParam),
            @ptrCast(&utf16_buff),
            utf16_buff.len * @sizeOf(u16),
        );

        result = @intCast(std.unicode.utf16LeToUtf8(name_out, utf16_buff[0..@intCast(result)]) catch 0);

        return name_out[0..@intCast(result)];
    }
};

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
            else => if (@intFromEnum(encoded) & 0x100 != 0)
                0xE000 | (@intFromEnum(encoded) & 0xFF)
            else
                @intFromEnum(encoded) & 0xFF,
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

test "Scancode: encode basic roundtrip" {
    // Test a few representative normal scancodes
    const cases = [_]u32{
        0x01, // escape
        0x1E, // a
        0x39, // space
        0x3B, // f1
        0x4B, // numpad_4
    };

    for (cases) |raw| {
        const encoded = Scancode.encode(raw);
        const decoded = Scancode.decode(encoded);
        try testing.expectEqual(raw, decoded);
    }
}

test "Scancode: encode extended keys roundtrip" {
    // Test extended (E0-prefixed) scancodes
    const cases = [_]u32{
        0xE01D, // right control
        0xE038, // right alt
        0xE047, // home
        0xE048, // up
        0xE04B, // left
        0xE04D, // right
        0xE050, // down
        0xE052, // insert
        0xE053, // delete
    };

    for (cases) |raw| {
        const encoded = Scancode.encode(raw);
        const decoded = Scancode.decode(encoded);
        try testing.expectEqual(raw, decoded);
    }
}

test "Scancode: encode pause/break roundtrip" {
    const raw: u32 = 0xE11D45;
    const encoded = Scancode.encode(raw);
    const decoded = Scancode.decode(encoded);
    try testing.expectEqual(raw, decoded);
}

test "Scancode: decode known values" {
    // Verify specific mappings against expected raw scancodes
    try testing.expectEqual(@as(u32, 0xE11D45), Scancode.decode(.pause));
    try testing.expectEqual(@as(u32, 0xE01D), Scancode.decode(.control_right));
    try testing.expectEqual(@as(u32, 0xE038), Scancode.decode(.alt_right));
    try testing.expectEqual(@as(u32, 0xE047), Scancode.decode(.home));
    try testing.expectEqual(@as(u32, 0x01), Scancode.decode(.escape));
}

test "Scancode: encode known raw values" {
    // Verify encoding of specific raw scancodes
    try testing.expectEqual(Scancode.pause, Scancode.encode(0xE11D45));
    try testing.expectEqual(Scancode.control_right, Scancode.encode(0xE01D));
    try testing.expectEqual(Scancode.alt_right, Scancode.encode(0xE038));
    try testing.expectEqual(Scancode.home, Scancode.encode(0xE047));
    try testing.expectEqual(Scancode.escape, Scancode.encode(0x01));
}

test "Scancode: encode all defined values roundtrip" {
    // Full enum coverage: encode->decode->encode cycle
    const it = std.meta.fields(Scancode);
    inline for (it) |field| {
        const encoded: Scancode = @field(Scancode, field.name);
        const raw = Scancode.decode(encoded);
        const reencoded = Scancode.encode(raw);
        try testing.expectEqual(encoded, reencoded);
    }
}
