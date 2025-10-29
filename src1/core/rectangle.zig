//! A generic rectangle structure with position and size.
//! Used to represent windows, monitors, and other rectangular areas.
const std = @import("std");
const core = @import("root.zig");

pub fn Rect(comptime T: type) type {
    return packed struct {
        const Self = @This();
        const Vec2 = core.Vec2(T);

        position: Vec2,
        size: Vec2,

        pub fn init(pos_x: T, pos_y: T, size_width: T, size_height: T) Self {
            return .{
                .position = .init(pos_x, pos_y),
                .size = .init(size_width, size_height),
            };
        }

        pub inline fn x(self: Self) T {
            return self.position.x();
        }

        pub inline fn y(self: Self) T {
            return self.position.y();
        }

        pub inline fn width(self: Self) T {
            return self.size.x();
        }

        pub inline fn height(self: Self) T {
            return self.size.y();
        }
    };
}

test "Rect: initialization and accessors" {
    const R = Rect(f32);
    const rect = R.init(10.0, 20.0, 640.0, 480.0);

    try std.testing.expectEqual(@as(f32, 10.0), rect.x());
    try std.testing.expectEqual(@as(f32, 20.0), rect.y());
    try std.testing.expectEqual(@as(f32, 640.0), rect.width());
    try std.testing.expectEqual(@as(f32, 480.0), rect.height());
}

test "init: integer type" {
    const R = Rect(i32);
    const rect = R.init(5, 15, 100, 200);

    try std.testing.expectEqual(@as(i32, 5), rect.x());
    try std.testing.expectEqual(@as(i32, 15), rect.y());
    try std.testing.expectEqual(@as(i32, 100), rect.width());
    try std.testing.expectEqual(@as(i32, 200), rect.height());
}

test "init: position and size fields" {
    const R = Rect(u16);
    const rect = R.init(1, 2, 3, 4);

    try std.testing.expectEqual(@as(u16, 1), rect.position.x());
    try std.testing.expectEqual(@as(u16, 2), rect.position.y());
    try std.testing.expectEqual(@as(u16, 3), rect.size.x());
    try std.testing.expectEqual(@as(u16, 4), rect.size.y());
}
