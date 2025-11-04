const std = @import("std");
const core = @import("core");
const pl = @import("platform");
const gpa = @import("gpa.zig");
const opt = @import("options.zig");
const kbd = @import("keyboard.zig");
const meta = std.meta;

const RingBuffer = core.RingBuffer;

fn InternalImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return struct {
            const Self = @This();

            var instance: Self = undefined;

            native: pl.Event,
            event_device_queue: RingBuffer(Event.InputDeviceId, opt.input_device_queue_size),

            pub fn init() !void {
                instance = .{
                    .native = try .init(),
                    .event_device_queue = .empty,
                };
            }

            pub fn deinit() void {
                instance.native.deinit();
            }

            // TODO: maybe use a circular buffer instead so we can remove error?
            pub fn pushEventDevice(id: Event.InputDeviceId) void {
                const last = instance.event_device_queue.peek();
                if (last) |existing_id| {
                    if (existing_id.equals(id)) {
                        // Duplicate event, ignore
                        return;
                    }
                } else {
                    instance.event_device_queue.push(id);
                }
            }
        };
    } else {
        return struct {
            const Self = @This();

            var instance: Self = undefined;

            native: pl.Event,

            pub fn init() !void {
                instance = .{
                    .native = try .init(),
                };
            }

            pub fn deinit() void {
                instance.native.deinit();
            }
        };
    }
}

pub const Internal = InternalImpl(opt.multi_input_device_support);

pub fn EventImpl(comptime multi_input_device_support: bool) type {
    if (multi_input_device_support) {
        return struct {
            const Self = @This();

            pub const InputDeviceId = union(enum) {
                keyboard: kbd.Keyboard.Id,
                mouse: u64,
                gamepad: u64,

                pub fn equals(self: InputDeviceId, other: InputDeviceId) bool {
                    return meta.eql(self, other);
                }
            };

            pub fn poll() !void {
                try Internal.instance.native.poll();
            }

            pub fn getEventDevice() ?InputDeviceId {
                return Internal.instance.event_device_queue.pop();
            }
        };
    } else {
        return struct {
            const Self = @This();

            pub fn poll() !void {
                try Internal.instance.native.poll();
            }
        };
    }
}

pub const Event = EventImpl(opt.multi_input_device_support);
