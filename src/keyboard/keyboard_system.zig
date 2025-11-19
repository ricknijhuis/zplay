const std = @import("std");
const builtin = @import("builtin");
const core = @import("core");
const opt = @import("options");
const debug = std.debug;

const Allocator = std.mem.Allocator;
const HandleSet = core.HandleSet;
const Deque = core.Deque;
const KeyboardState = @import("keyboard_state.zig").KeyboardState;
const Key = @import("keys.zig").Key;

pub fn KeyboardSystem(comptime multi_device: bool) type {
    return struct {
        pub const Self = @This();
        const KeyboardStateT = KeyboardState(multi_device);
        const Platform = switch (builtin.os.tag) {
            .windows => @import("win32/keyboard_system.zig").KeyboardSystemWin32,
            else => @compileError("Platform not 'yet' supported"),
        };

        platform: Platform,
        keyboards: HandleSet(KeyboardState(multi_device)),

        pub fn init() !Self {
            return .{
                .platform = try .init(),
                .keyboards = .empty,
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.platform.deinit();
            self.keyboards.deinit(gpa);
        }

        pub fn reset(self: *Self) void {
            for (self.keyboards.items) |*kbd| {
                for (kbd.state.values[0..]) |*state| {
                    state.reset();
                }
            }
        }

        pub fn getScancodeName(self: *Self, key: Key, name_out: []u8) []const u8 {
            return self.platform.getScancodeName(key, name_out);
        }

        pub fn process(self: *Self, key: Key, down: bool) void {
            for (self.keyboards.items) |*kbd| {
                kbd.state.getPtr(key).update(down);
            }
        }

        /// Process a key event, filtering by keyboard id
        pub fn processFiltered(self: *Self, keyboard: KeyboardStateT.Id, key: Key, down: bool) void {
            comptime debug.assert(opt.enable_keyboard_multiple_devices);

            for (self.keyboards.items) |*kbd| {
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
}

test "KeyboardSystem: process sets key down state" {
    const gpa = std.testing.allocator;
    var system: KeyboardSystem(false) = try .init();
    defer system.deinit(gpa);

    _ = try system.keyboards.addOne(gpa);
    _ = try system.keyboards.addOne(gpa);

    system.process(.a, true);

    for (system.keyboards.items) |*kbd| {
        try std.testing.expect(kbd.state.get(.a).down);
    }
}

test "KeyboardSystem: processFiltered sets key down state for matching keyboard id" {
    const gpa = std.testing.allocator;
    var system: KeyboardSystem(true) = try .init();
    defer system.deinit(gpa);

    _ = try system.keyboards.addOne(gpa);
    _ = try system.keyboards.addOne(gpa);

    system.keyboards.items[0] = .init();
    system.keyboards.items[1] = .init();

    system.keyboards.items[0].filter(@enumFromInt(0));
    system.keyboards.items[1].filter(@enumFromInt(1));

    system.processFiltered(@enumFromInt(1), .a, true);

    try std.testing.expect(!system.keyboards.items[0].state.get(.a).down);
    try std.testing.expect(system.keyboards.items[1].state.get(.a).down);
}

test "KeyboardSystem: GetKeyName returns correct name" {
    const gpa = std.testing.allocator;
    var system: KeyboardSystem(false) = try .init();
    defer system.deinit(gpa);

    var buffer: [16:0]u8 = undefined;
    const name = system.getKeyName(.a, &buffer);
    try std.testing.expectEqualStrings(name, "A");
}
