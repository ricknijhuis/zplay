/// We have 2 seperate keyboard implementations, one that supports identifying multiple keyboards
/// and one that only supports a single keyboard.
/// This does NOT mean that the single keyboard implementation cannot handle multiple keyboards, only that the developer cannot
/// distinguish between them. For obvious reasons the multi keyboard support is more complex and thus has a small overhead.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const app = @import("app.zig");
const opt = @import("options.zig");
const meta = core.meta;

const Allocator = std.mem.Allocator;
const EnumArray = std.EnumArray;

const instance = &app.Internal.instance;

fn InternalImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return InternalMultipleDevicesImpl;
    } else {
        return InternalSingleDeviceImpl;
    }
}

const Impl = switch (builtin.os.tag) {
    .windows => @import("win32/Keyboard.zig"),
    else => @compileError("Platform not 'yet' supported"),
};

const ScancodeIndexer = std.enums.EnumIndexer(Impl.Scancode);
const KeyIndexer = std.enums.EnumIndexer(KeyboardKey);

// Internal representation of keyboards, supports multiple devices
const InternalMultipleDevicesImpl = struct {
    pub const Id = core.Id(InternalMultipleDevicesImpl);

    filter_buffer: [opt.keyboard_filter_size]Id,
    filter_count: usize,
    state: EnumArray(Keyboard.Key, KeyboardKeyState),

    pub fn reset() void {
        for (instance.keyboards.items) |*kbd| {
            for (kbd.state.values) |*state| {
                state.reset();
            }
        }
    }

    pub fn process(key: Keyboard.Key, down: bool) void {
        for (instance.keyboards.items) |*kbd| {
            kbd.state.getPtr(key).update(down);
        }
    }

    pub fn processFiltered(keyboard: Id, key: Keyboard.Key, down: bool) void {
        for (instance.keyboards.items) |*kbd| {
            if (kbd.filter_count == 0) {
                kbd.state.getPtr(key).update(down);
            } else {
                for (kbd.filter_buffer[0..kbd.filter_count]) |id| {
                    if (id == .none or id == keyboard) {
                        kbd.state.getPtr(key).update(down);
                    }
                }
            }
        }
    }
};

// Internal representation of keyboards, supports single device only
const InternalSingleDeviceImpl = struct {
    pub const Id = core.Id(InternalSingleDeviceImpl);

    state: EnumArray(Keyboard.Key, KeyboardKeyState),

    pub fn process(key: Keyboard.Key, down: bool) void {
        instance.keyboards.items[0].state.getPtr(key).update(down);
    }
    pub fn reset() void {
        for (instance.keyboards.items[0].state.values[0..]) |*state| {
            state.reset();
        }
    }
};

fn KeyboardImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return KeyboardMultipleDevices;
    } else {
        return KeyboardSingleDevice;
    }
}

fn SharedKeyboardImpl(comptime Self: type) type {
    return struct {
        pub const Key = KeyboardKey;
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
    };
}

const KeyboardMultipleDevices = struct {
    pub const Key = KeyboardKey;
    const HandleT = core.HandleSet(Internal).Handle;

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

        return .{ .value = handle };
    }

    pub const isKeyDown = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyDown;
    pub const isKeyUp = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyUp;
    pub const isKeyPressed = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyPressed;
    pub const isKeyReleased = SharedKeyboardImpl(KeyboardMultipleDevices).isKeyReleased;
};

const KeyboardSingleDevice = struct {
    pub const Key = KeyboardKey;
    const HandleT = core.HandleSet(Internal).Handle;

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
};

pub const Internal = InternalImpl(opt.multi_input_device_support);
pub const Keyboard = KeyboardImpl(opt.multi_input_device_support);

/// Represents the last known state of a key, mainly used internally.
pub const KeyboardKeyState = packed struct(u8) {
    /// If set the key is currently held down
    down: bool,
    /// If set the key state has changed at least once during the frame
    /// This allows to detect key presses and releases
    transitioned: bool,
    _: u6 = 0,

    /// The default 'up' state of a key.
    pub const up: KeyboardKeyState = .{
        .down = false,
        .transitioned = false,
    };

    /// Resets the transitioned state of the key.
    pub fn reset(self: *KeyboardKeyState) void {
        self.transitioned = false;
    }

    /// Updates the key state based on whether it is currently down or up.
    /// using the previous state to determine if a transition has occurred.
    fn update(self: *KeyboardKeyState, down: bool) void {
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

/// These keys are based on the US keyboard layout and don't change with different layouts.
/// They act as physical key identifiers(Scancodes). And thus are safe to use for keybindings.
/// On US layout key key W returns Key.w while on Azerty layout key Z returns Key.w
const KeyboardKey = enum(u32) {
    escape,
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"0",
    minus,
    equals,
    backspace,
    tab,
    q,
    w,
    e,
    r,
    t,
    y,
    u,
    i,
    o,
    p,
    bracket_left,
    bracket_right,
    enter,
    control_left,
    a,
    s,
    d,
    f,
    g,
    h,
    j,
    k,
    l,
    semicolon,
    apostrophe,
    grave,
    shift_left,
    backslash,
    z,
    x,
    c,
    v,
    b,
    n,
    m,
    comma,
    period,
    slash,
    shift_right,
    numpad_multiply,
    alt_left,
    space,
    caps_lock,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    num_lock,
    scroll_lock,
    numpad_7,
    numpad_8,
    numpad_9,
    numpad_minus,
    numpad_4,
    numpad_5,
    numpad_6,
    numpad_plus,
    numpad_1,
    numpad_2,
    numpad_3,
    numpad_0,
    numpad_period,
    alt_print_screen,
    bracket_angle,
    f11,
    f12,
    oem_1,
    oem_2,
    oem_3,
    erase_eof,
    oem_4,
    oem_5,
    zoom,
    help,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    oem_6,
    katakana,
    oem_7,
    f24,
    sbcschar,
    convert,
    nonconvert,
    media_previous,
    media_next,
    numpad_enter,
    control_right,
    volume_mute,
    launch_app2,
    media_play,
    media_stop,
    volume_down,
    volume_up,
    browser_home,
    numpad_divide,
    print_screen,
    alt_right,
    cancel,
    home,
    arrow_up,
    page_up,
    arrow_left,
    arrow_right,
    end,
    arrow_down,
    page_down,
    insert,
    delete,
    meta_left,
    meta_right,
    application,
    power,
    sleep,
    wake,
    browser_search,
    browser_favorites,
    browser_refresh,
    browser_stop,
    browser_forward,
    browser_back,
    launch_app1,
    launch_email,
    launch_media,
    pause,

    pub const last = meta.enums.greatest(KeyboardKey);
};
