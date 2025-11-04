const std = @import("std");
const core = @import("core");
const pl = @import("platform");
const gpa = @import("gpa.zig");
const opt = @import("options.zig");
const debug = std.debug;

const HandleSet = core.HandleSet;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const EnumArray = std.EnumArray;

fn InternalImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        debug.assert(opt.keyboard_filter_size != 0);

        return struct {
            const Self = @This();

            pub var instance: HandleSet(Self) = undefined;

            pub const Id = enum(u64) {
                none = 0,
                _,

                pub fn fromInt(value: anytype) Id {
                    return @as(Id, @enumFromInt(value));
                }
            };
            filter_buffer: [opt.keyboard_filter_size]Id,
            filter_count: u32,
            state: EnumArray(Keyboard.Key, Keyboard.Key.State),

            pub fn init() !void {
                instance = .empty;
            }

            pub fn deinit() void {
                instance.deinit(gpa.Internal.instance);
            }

            pub fn process(keyboard: pl.Keyboard, scancode: pl.Keyboard.Scancode, down: bool) void {
                for (instance.items) |*kbd| {
                    if (kbd.filter_count == 0) {
                        const key_state = if (down) Keyboard.Key.State.down else Keyboard.Key.State.up;
                        kbd.state.set(@as(Keyboard.Key, @enumFromInt(scancode_indexer.indexOf(scancode))), key_state);
                    } else {
                        for (kbd.filter_buffer[0..kbd.filter_count]) |id| {
                            if (id == .none or id == Id.fromInt(keyboard.getId())) {
                                const key_state = if (down) Keyboard.Key.State.down else Keyboard.Key.State.up;
                                kbd.state.set(@as(Keyboard.Key, @enumFromInt(scancode_indexer.indexOf(scancode))), key_state);
                            }
                        }
                    }
                }
            }
        };
    } else {
        return struct {
            const Self = @This();

            pub var instance: HandleSet(Self) = undefined;

            state: EnumArray(Keyboard.Key, Keyboard.Key.State),

            pub fn init() !void {
                instance = .empty;
            }

            pub fn deinit() void {
                Internal.instance.deinit(gpa.Internal.instance);
            }

            pub fn process(keyboard: pl.Keyboard, scancode: pl.Keyboard.Scancode, down: bool) void {
                // TODO: Might be improved by instead of looping just always get the first item as there is only one keyboard instance
                // Keyboard.init should ensure there is always one instance
                _ = keyboard;
                for (instance.items) |*kbd| {
                    const key_state = if (down) Keyboard.Key.State.down else Keyboard.Key.State.up;
                    kbd.state.set(@as(Keyboard.Key, @enumFromInt(scancode_indexer.indexOf(scancode))), key_state);
                }
            }
        };
    }
}

fn KeyboardImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return struct {
            const Self = @This();

            pub const Id = Internal.Id;
            pub const Key = KeyboardKey;

            const HandleT = HandleSet(Internal).Handle;

            /// The actual handle value
            value: HandleT,

            /// Initializes a keyboard and returns a handle to it. This is a virtual representation and not
            /// linked to any hardware. If you want the keyboard to process data of specific hardware use the filter method
            /// Keys are initialized with all keys in .up state.
            pub fn init() !Self {
                const handle = try Internal.instance.addOneExact(gpa.Internal.instance);
                const keyboard = Internal.instance.getPtr(handle);

                keyboard.filter_buffer = undefined;
                keyboard.filter_count = 0;
                keyboard.state = .initFill(.up);

                return .{ .value = handle };
            }

            /// Resets key state to be in up position
            /// Asserts whether handle is valid
            /// Asserts whether handle is valid
            pub fn reset(self: Self) void {
                var keyboard = Internal.instance.getPtr(self.value);
                keyboard.state = .initFill(.up);
            }

            /// Adds a device id to the filter, from now on only input comming from devices in the filter will be processed.
            /// The Id is linked to an actual hardware device.
            /// Asserts whether handle is valid
            pub fn filter(self: Self, id: Id) void {
                var keyboard = Internal.instance.getPtr(self.value);
                debug.assert(keyboard.filter_count < keyboard.filter_buffer.len);
                keyboard.filter_buffer[keyboard.filter_count] = id;
                keyboard.filter_count += 1;
            }

            /// Returns the list of current devices that are filtered.
            /// Asserts whether handle is valid
            pub fn filters(self: Self) []Id {
                const keyboard = Internal.instance.getPtr(self.value);
                return keyboard.filter_buffer[0..keyboard.filter_count];
            }

            /// Checks if last known state of given key is down
            /// Asserts whether handle is valid
            pub fn isKeyDown(self: Self, key: Key) bool {
                var keyboard = Internal.instance.getPtr(self.value);
                return keyboard.state.get(@as(Keyboard.Key, key)) == .down;
            }

            /// Checks if last know state of given key is up
            /// Asserts whether handle is valid
            pub fn isKeyUp(self: Self, key: Key) bool {
                return !self.isKeyDown(key);
            }

            /// Free's any resources and invalidates the handle
            /// Asserts whether handle is valid
            pub fn deinit(self: *Self) void {
                Internal.instance.swapRemove(self.value);
                self.value = .none;
            }

            /// Returns whether the handle points to a valid resource
            pub fn isValid(self: Self) bool {
                return Internal.instance.contains(self.value);
            }

            /// Returns the platforms specific scancode
            pub fn getScancode(key: Key) pl.Keyboard.Scancode {
                return @enumFromInt(key_indexer.indexOf(key));
            }
        };
    } else {
        return struct {
            const Self = @This();

            pub const Key = KeyboardKey;

            const HandleT = HandleSet(Internal).Handle;

            /// The actual handle value
            value: HandleT,

            /// Initializes a keyboard and returns a handle to it. This is a virtual representation and not
            /// linked to any hardware.
            /// Keys are initialized with all keys in .up state.
            pub fn init() !Self {
                const handle = try Internal.instance.addOneExact(gpa.Internal.instance);
                const keyboard = Internal.instance.getPtr(handle);

                keyboard.state = .initFill(.up);

                return .{ .value = handle };
            }

            /// Resets key state to be in up position
            /// Asserts whether handle is valid
            pub fn reset(self: Self) void {
                var keyboard = Internal.instance.getPtr(self.value);
                keyboard.state = .initFill(.up);
            }

            /// Checks if last known state of given key is down
            /// Asserts whether handle is valid
            pub fn isKeyDown(self: Self, key: Key) bool {
                var keyboard = Internal.instance.getPtr(self.value);
                return keyboard.state.get(@as(Keyboard.Key, key)) == .down;
            }

            /// Checks if last know state of given key is up
            /// Asserts whether handle is valid
            pub fn isKeyUp(self: Self, key: Key) bool {
                return !self.isKeyDown(key);
            }

            /// Free's any resources and invalidates the handle
            /// Asserts whether handle is valid
            pub fn deinit(self: *Self) void {
                Internal.instance.swapRemove(self.value);
                self.value = .none;
            }

            pub fn isValid(self: Self) bool {
                return Internal.instance.contains(self.value);
            }

            /// Returns the platforms specific scancode
            pub fn getScancode(key: Key) pl.Keyboard.Scancode {
                return @enumFromInt(key_indexer.indexOf(key));
            }
        };
    }
}

/// For internal use. Is not exposed through root.zig
pub const Internal = InternalImpl(opt.multi_input_device_support);

/// Handle to a virtual representation of a keyboard
/// If root defines 'multi_input_device_support = true', filter methods will be allowed
/// to only receive events of given hardware
pub const Keyboard = KeyboardImpl(opt.multi_input_device_support);

const scancode_indexer = std.enums.EnumIndexer(pl.Keyboard.Scancode);
const key_indexer = std.enums.EnumIndexer(KeyboardKey);

/// These keys are based on the US keyboard layout and don't change with different layouts.
/// They act as physical key identifiers(Scancodes). And thus are safe to use for keybindings.
/// On US layout key key W returns Key.w while on Azerty layout key Z returns Key.w
const KeyboardKey = enum(u32) {
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
