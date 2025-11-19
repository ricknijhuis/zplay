//! A generic rectangle structure with position and size.
//! Used to represent windows, monitors, and other rectangular areas.
const std = @import("std");
const core = @import("root.zig");

pub fn Rect(comptime T: type) type {
    return packed struct {
        const Self = @This();
        const Vec2 = core.Vec2(T);

        /// Position on the x axis of the top left corner of the rectangle
        x: T,
        /// Position on the y axis of the top left corner of the rectangle
        y: T,
        /// Width of the rectangle
        width: T,
        /// Height of the rectangle
        height: T,

        pub fn init(pos_x: T, pos_y: T, width: T, height: T) Self {
            return .{
                .position = .init(pos_x, pos_y),
                .size = .init(width, height),
            };
        }

        /// Returns the width and height in a vec2
        pub fn size(self: Self) Vec2 {
            return .init(self.width, self.height);
        }

        /// Returns the x and y in a vec2
        pub fn position(self: Self) Vec2 {
            return self.min();
        }

        /// Returns the x and y in a vec2
        pub fn min(self: Self) Vec2 {
            return .init(self.x, self.y);
        }

        /// Returns the x and y of the bottom right corner of the rectangle
        pub fn max(self: Self) Vec2 {
            return .init(self.x + self.width, self.y + self.height);
        }

        /// Returns the area that one rect intersects with the other
        pub fn intersection(self: Self, other: Self) T {
            const min_pos = @max(self.min().data, other.min().data);
            const max_pos = @min(self.max().data, other.max().data);
            const full_size = @max(Vec2.VectorT{ 0, 0 }, max_pos - min_pos);
            return @reduce(.Mul, full_size);
        }
    };
}
test "Rect: intersection full overlap" {
    const a: Rect(i32) = .init(0, 0, 10, 10);
    const b: Rect(i32) = .init(0, 0, 10, 10);
    try std.testing.expectEqual(@as(i32, 100), a.intersection(b));
}

test "Rect: intersection partial overlap" {
    const a: Rect(i32) = .init(0, 0, 10, 10);
    const b: Rect(i32) = .init(5, 5, 10, 10);
    try std.testing.expectEqual(@as(i32, 25), a.intersection(b));
}

test "Rect: intersection edge touch" {
    const a: Rect(i32) = .init(0, 0, 10, 10);
    const b: Rect(i32) = .init(10, 0, 10, 10);
    try std.testing.expectEqual(@as(i32, 0), a.intersection(b));
}

test "Rect: intersection no overlap" {
    const a: Rect(i32) = .init(0, 0, 10, 10);
    const b: Rect(i32) = .init(20, 20, 5, 5);
    try std.testing.expectEqual(@as(i32, 0), a.intersection(b));
}

test "Rect: intersection contained rect" {
    const a: Rect(i32) = .init(0, 0, 10, 10);
    const b: Rect(i32) = .init(2, 2, 4, 4);
    try std.testing.expectEqual(@as(i32, 16), a.intersection(b));
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
