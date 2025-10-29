const std = @import("std");
const core = @import("core");
const context = @import("context.zig");
const Keyboard = @import("Keyboard.zig");
const HandleSet = core.HandleSet;
const Handle = HandleSet(Keyboard).Handle;

const KeyboardHandle = @This();

/// Error type for keyboard handle initialization
pub const Error = error{
    FailedToInitialize,
} || std.mem.Allocator.Error;

const instance = &context.instance;

/// Handle to the keyboard
handle: Handle,

/// Initialize the keyboard, if no keyboard is initialized
pub fn init() Error!KeyboardHandle {
    const handle = try instance.keyboards.addOneExact(instance.gpa);
    const keyboard = instance.keyboards.getPtr(handle);

    keyboard.native = try .init();

    // Set default key state to up.
    keyboard.state = .initFill(.up);

    return .{ .handle = handle };
}

pub fn getKeyState(self: KeyboardHandle, key: Key) Key.State {
    const keyboard = instance.keyboards.getPtr(self.handle);
    return keyboard.state.get(key);
}

/// These keys are based on the US keyboard layout and don't change with different layouts.
/// They act as physical key identifiers(Scancodes). And thus are safe to use for keybindings.
/// On US layout key key W returns Key.w while on Azerty layout key Z returns Key.w
pub const Key = enum(u32) {
    /// Represents the last known state of a key
    pub const State = enum(u8) {
        /// Key is up
        up = 1,
        /// Key is down
        down = 2,
    };

    /// Represents a user action on a key
    pub const Action = enum(u8) {
        /// Key was pressed
        press,
        /// Key was released
        release,
    };

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
};
