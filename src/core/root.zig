const vector = @import("vector.zig");
const rectangle = @import("rectangle.zig");
const handle_set = @import("handle_set.zig");

pub const asserts = @import("asserts.zig");

pub const Vec2 = vector.Vec2;
pub const Vec3 = vector.Vec3;
pub const Vec4 = vector.Vec4;

pub const Vec2i32 = Vec2(i32);
pub const Vec2u32 = Vec2(u32);
pub const Vec2f32 = Vec2(f32);
pub const Vec3i32 = Vec3(i32);
pub const Vec3u32 = Vec3(u32);
pub const Vec3f32 = Vec3(f32);
pub const Vec4i32 = Vec3(i32);
pub const Vec4u32 = Vec3(u32);
pub const Vec4f32 = Vec3(f32);

pub const Recti32 = rectangle.Rect(i32);
pub const Rectu32 = rectangle.Rect(u32);
pub const Rectf32 = rectangle.Rect(f32);

pub const HandleSet = handle_set.HandleSet;

pub const StringTable = @import("StringTable.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
