const builtin = @import("builtin");
const core = @import("core");
const mods = @import("modules");

pub const asserts = core.asserts;
pub const errors = core.errors;

pub const Vec2i32 = core.Vec2i32;
pub const Vec2u32 = core.Vec2u32;
pub const Vec2f32 = core.Vec2f32;
pub const Vec2f64 = core.Vec2f64;
pub const Vec3i32 = core.Vec3i32;
pub const Vec3u32 = core.Vec3u32;
pub const Vec3f32 = core.Vec3f32;
pub const Vec3f64 = core.Vec3f64;
pub const Vec4i32 = core.Vec4i32;
pub const Vec4u32 = core.Vec4u32;
pub const Vec4f32 = core.Vec4f32;
pub const Vec4f64 = core.Vec4f64;

pub const HandleSet = core.HandleSet;

pub const MonitorHandle = mods.MonitorHandle;
pub const WindowHandle = mods.WindowHandle;
pub const Events = mods.Events;
pub const KeyboardHandle = mods.KeyboardHandle;

pub const init = mods.context.init;
pub const deinit = mods.context.deinit;

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
