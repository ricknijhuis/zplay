//! A generic rectangle structure with position and size.
//! Used to represent windows, monitors, and other rectangular areas.
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
            return self.size.x();
        }
    };
}
