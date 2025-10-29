//! Vector math library providing Vec2, Vec3, and Vec4 types with common operations.
//! When extending this library, make sure to only add functions that make sense for all vector sizes to the VecImpl struct.
//! Otherwise, add them to the specific Vec2, Vec3, or Vec4 structs.
const std = @import("std");

pub const VecComponent = enum { x, y, z, w };

pub fn Vec2(comptime T: type) type {
    return packed struct {
        const Self = @This();
        const VecImpl = Vec(Self);

        pub const ScalarT = T;
        pub const VectorT = @Vector(2, T);

        data: VectorT,

        pub fn init(comp_x: ScalarT, comp_y: ScalarT) Self {
            return .{ .data = .{ comp_x, comp_y } };
        }

        pub const n = 2;
        pub const empty = VecImpl.empty;
        pub const x = VecImpl.x;
        pub const y = VecImpl.y;
        pub const xy = VecImpl.xy;
        pub const abs = VecImpl.abs;
        pub const to = VecImpl.to;
        pub const mul = VecImpl.mul;
        pub const div = VecImpl.div;
        pub const add = VecImpl.add;
        pub const sub = VecImpl.sub;
        pub const ceil = VecImpl.ceil;
        pub const divFloor = VecImpl.divFloor;
        pub const divFloorScalar = VecImpl.divFloorScalar;
        pub const divScalar = VecImpl.divScalar;
        pub const mulScalar = VecImpl.mulScalar;
        pub const addScalar = VecImpl.addScalar;
        pub const subScalar = VecImpl.subScalar;
        pub const splat = VecImpl.splat;
        pub const len = VecImpl.len;
        pub const lenSq = VecImpl.lenSq;
        pub const distance = VecImpl.distance;
    };
}

pub fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();
        const VecImpl = Vec(Self);

        pub const ScalarT = T;
        pub const VectorT = @Vector(3, T);

        data: VectorT,

        pub fn init(comp_x: ScalarT, comp_y: ScalarT, comp_z: ScalarT) Self {
            return .{ .data = .{ comp_x, comp_y, comp_z } };
        }

        pub const n = 3;
        pub const empty = VecImpl.empty;
        pub const x = VecImpl.x;
        pub const y = VecImpl.y;
        pub const z = VecImpl.z;
        pub const xy = VecImpl.xy;
        pub const xyz = VecImpl.xyz;
        pub const abs = VecImpl.abs;
        pub const to = VecImpl.to;
        pub const mul = VecImpl.mul;
        pub const div = VecImpl.div;
        pub const add = VecImpl.add;
        pub const sub = VecImpl.sub;
        pub const ceil = VecImpl.ceil;
        pub const divFloor = VecImpl.divFloor;
        pub const divFloorScalar = VecImpl.divFloorScalar;
        pub const divScalar = VecImpl.divScalar;
        pub const mulScalar = VecImpl.mulScalar;
        pub const addScalar = VecImpl.addScalar;
        pub const subScalar = VecImpl.subScalar;
        pub const splat = VecImpl.splat;
        pub const len = VecImpl.len;
        pub const lenSq = VecImpl.lenSq;
        pub const distance = VecImpl.distance;

        pub inline fn swizzle(self: Self, comptime comp_x: VecComponent, comptime comp_y: VecComponent, comptime comp_z: VecComponent) Self {
            return .{ .data = @shuffle(ScalarT, self.data, undefined, [3]ScalarT{
                @intFromEnum(comp_x),
                @intFromEnum(comp_y),
                @intFromEnum(comp_z),
            }) };
        }

        pub inline fn cross(self: Self, other: Self) Self {
            const s1 = self.swizzle(.y, .z, .x)
                .mul(other.swizzle(.z, .x, .y));
            const s2 = self.swizzle(.z, .x, .y)
                .mul(other.swizzle(.y, .z, .x));
            return s1.sub(s2);
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return packed struct {
        const Self = @This();
        const VecImpl = Vec(Self);

        pub const ScalarT = T;
        pub const VectorT = @Vector(4, T);

        data: VectorT,

        pub fn init(comp_x: ScalarT, comp_y: ScalarT, comp_z: ScalarT, comp_w: ScalarT) Self {
            return .{ .data = @as(VectorT, .{ comp_x, comp_y, comp_z, comp_w }) };
        }

        pub const n = 4;
        pub const empty = VecImpl.empty;
        pub const x = VecImpl.x;
        pub const y = VecImpl.y;
        pub const z = VecImpl.z;
        pub const w = VecImpl.w;
        pub const xy = VecImpl.xy;
        pub const xyz = VecImpl.xyz;
        pub const xyzw = VecImpl.xyzw;
        pub const abs = VecImpl.abs;
        pub const to = VecImpl.to;
        pub const mul = VecImpl.mul;
        pub const div = VecImpl.div;
        pub const add = VecImpl.add;
        pub const sub = VecImpl.sub;
        pub const ceil = VecImpl.ceil;
        pub const divFloor = VecImpl.divFloor;
        pub const divFloorScalar = VecImpl.divFloorScalar;
        pub const divScalar = VecImpl.divScalar;
        pub const mulScalar = VecImpl.mulScalar;
        pub const addScalar = VecImpl.addScalar;
        pub const subScalar = VecImpl.subScalar;
        pub const splat = VecImpl.splat;
        pub const len = VecImpl.len;
        pub const lenSq = VecImpl.lenSq;
        pub const distance = VecImpl.distance;
    };
}

pub fn Vec(comptime ImplT: type) type {
    return struct {
        const Self = ImplT;
        const VectorT = Self.VectorT;
        const ScalarT = Self.ScalarT;

        pub const empty: Self = .splat(0);

        pub inline fn x(self: Self) ScalarT {
            return self.data[0];
        }

        pub inline fn y(self: Self) ScalarT {
            return self.data[1];
        }

        pub inline fn z(self: Self) ScalarT {
            comptime std.debug.assert(Self.n > 2);
            return self.data[2];
        }

        pub inline fn w(self: Self) ScalarT {
            comptime std.debug.assert(Self.n > 3);
            return self.data[3];
        }

        pub inline fn xy(self: Self) @Vector(2, ScalarT) {
            return .{ self.data[0], self.data[1] };
        }

        pub inline fn xyz(self: Self) @Vector(3, ScalarT) {
            return .{ self.data[0], self.data[1], self.data[2] };
        }

        pub inline fn xyzw(self: Self) @Vector(4, ScalarT) {
            return .{ self.data[0], self.data[1], self.data[2], self.data[3] };
        }

        pub inline fn splat(scalar: ScalarT) Self {
            return .{ .data = @splat(scalar) };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return .{ .data = self.data * other.data };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return .{ .data = self.data / other.data };
        }

        pub inline fn add(self: Self, other: Self) Self {
            return .{ .data = self.data + other.data };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return .{ .data = self.data - other.data };
        }

        pub inline fn mulScalar(self: Self, scalar: ScalarT) Self {
            return .{ .data = self.data * @as(VectorT, @splat(scalar)) };
        }

        pub inline fn divScalar(self: Self, scalar: ScalarT) Self {
            return .{ .data = self.data / @as(VectorT, @splat(scalar)) };
        }

        pub inline fn divFloorScalar(self: Self, scalar: ScalarT) Self {
            return .{ .data = @divFloor(self.data, @as(Self.VectorT, @splat(scalar))) };
        }

        pub inline fn divFloor(self: Self, other: Self) Self {
            return .{ .data = @divFloor(self.data, other.data) };
        }

        pub inline fn addScalar(self: Self, scalar: ScalarT) Self {
            return .{ .data = self.data + @as(VectorT, @splat(scalar)) };
        }

        pub inline fn subScalar(self: Self, scalar: ScalarT) Self {
            return .{ .data = self.data - @as(VectorT, @splat(scalar)) };
        }

        pub inline fn dot(self: Self, other: *const Self) ScalarT {
            return @reduce(.Add, self.data * other.data);
        }

        pub inline fn ceil(self: Self) Self {
            return .{ .data = @ceil(self.data) };
        }

        pub inline fn abs(self: Self) Self {
            return .{
                .data = switch (@typeInfo(ScalarT)) {
                    inline .int => |IntType| switch (IntType.signedness) {
                        .signed => @intCast(@abs(self.data)),
                        .unsigned => @abs(self.data),
                    },
                    inline .float => @abs(self.data),
                    else => @compileError("Unsupported type for abs(): " ++ @typeName(ScalarT)),
                },
            };
        }

        pub inline fn normalize(self: Self) Self {
            const norm = std.math.sqrt(self.dot(self));

            if (norm < std.math.floatEps(ScalarT)) {
                @branchHint(.unlikely);
                return .empty;
            }

            return self.mulScalar(1.0 / norm);
        }

        pub inline fn len(self: Self) ScalarT {
            switch (@typeInfo(ScalarT)) {
                .int => |IntType| switch (IntType.signedness) {
                    .signed => return @intCast(std.math.sqrt(self.to(u32).lenSq())),
                    .unsigned => return std.math.sqrt(self.lenSq()),
                },
                else => {
                    return std.math.sqrt(lenSq(self));
                },
            }
        }

        pub fn lenSq(self: Self) ScalarT {
            return @reduce(.Add, self.data * self.data);
        }

        pub fn distance(self: Self, other: Self) ScalarT {
            return other.sub(self).len();
        }

        pub inline fn to(self: Self, comptime NewScalarT: type) VecTypeForN(Self.n, NewScalarT) {
            // const NewVecT = VecTypeForN(Self.n, NewScalarT);
            const from_info = @typeInfo(ScalarT);
            const to_info = @typeInfo(NewScalarT);

            if (from_info == .int and to_info == .float) {
                return .{ .data = @floatFromInt(self.data) };
            } else if (from_info == .float and to_info == .int) {
                return .{ .data = @intFromFloat(self.data) };
            } else if (from_info == .int and to_info == .int) {
                return .{ .data = @intCast(self.data) };
            } else if (from_info == .float and to_info == .float) {
                return .{ .data = @floatCast(self.data) };
            } else {
                @compileError("Unsupported conversion from " ++ @typeName(ScalarT) ++ " to " ++ @typeName(NewScalarT));
            }
        }
    };
}

pub fn VecTypeForN(comptime n: usize, comptime T: type) type {
    return switch (n) {
        2 => Vec2(T),
        3 => Vec3(T),
        4 => Vec4(T),
        else => @compileError("Unsupported vector dimension: " ++ std.fmt.comptimePrint("{}", .{n})),
    };
}

test "Vec2: initialization and components" {
    const V = Vec2(f32);
    const v = V.init(3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 3.0), v.x());
    try std.testing.expectEqual(@as(f32, 4.0), v.y());
}

test "Vec2: add and sub" {
    const V = Vec2(f32);
    const a = V.init(2.0, 3.0);
    const b = V.init(1.0, 5.0);

    const sum = a.add(b);
    try std.testing.expectEqual(@as(f32, 3.0), sum.x());
    try std.testing.expectEqual(@as(f32, 8.0), sum.y());

    const diff = a.sub(b);
    try std.testing.expectEqual(@as(f32, 1.0), diff.x());
    try std.testing.expectEqual(@as(f32, -2.0), diff.y());
}

test "Vec2: scalar arithmetic" {
    const V = Vec2(f32);
    const v = V.init(2.0, 4.0);

    const add_s = v.addScalar(1.0);
    try std.testing.expectEqual(@as(f32, 3.0), add_s.x());
    try std.testing.expectEqual(@as(f32, 5.0), add_s.y());

    const sub_s = v.subScalar(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), sub_s.x());
    try std.testing.expectEqual(@as(f32, 3.0), sub_s.y());

    const mul_s = v.mulScalar(2.0);
    try std.testing.expectEqual(@as(f32, 4.0), mul_s.x());
    try std.testing.expectEqual(@as(f32, 8.0), mul_s.y());

    const div_s = v.divScalar(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), div_s.x());
    try std.testing.expectEqual(@as(f32, 2.0), div_s.y());
}

test "Vec2: length and distance" {
    const V = Vec2(f32);
    const a = V.init(3.0, 4.0);
    const b = V.init(6.0, 8.0);

    // len should be sqrt(3² + 4²) = 5
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), a.len(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), a.lenSq(), 1e-6);

    // distance between (3,4) and (6,8) = 5
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), a.distance(b), 1e-6);
}

test "Vec2: abs and splat" {
    const V = Vec2(i32);
    const v = V.init(-3, 4);
    const abs_v = v.abs();

    try std.testing.expectEqual(@as(i32, 3), abs_v.x());
    try std.testing.expectEqual(@as(i32, 4), abs_v.y());

    const s = V.splat(5);
    try std.testing.expectEqual(@as(i32, 5), s.x());
    try std.testing.expectEqual(@as(i32, 5), s.y());
}

test "Vec2: ceil, divFloor, to" {
    const V = Vec2(f32);
    const v = V.init(1.2, 3.8);
    const c = v.ceil();
    try std.testing.expectEqual(@as(f32, 2.0), c.x());
    try std.testing.expectEqual(@as(f32, 4.0), c.y());

    const a = V.init(5.0, 9.0);
    const b = V.init(2.0, 4.0);
    const divf = a.divFloor(b);
    try std.testing.expectEqual(@as(f32, 2.0), divf.x());
    try std.testing.expectEqual(@as(f32, 2.0), divf.y());

    const to = v.to(f32);
    try std.testing.expectEqual(@as(f32, 1.2), to.x());
    try std.testing.expectEqual(@as(f32, 3.8), to.y());
}

test "Vec3: initialization and components" {
    const V = Vec3(f32);
    const v = V.init(1.0, 2.0, 3.0);

    try std.testing.expectEqual(@as(f32, 1.0), v.x());
    try std.testing.expectEqual(@as(f32, 2.0), v.y());
    try std.testing.expectEqual(@as(f32, 3.0), v.z());
}

test "Vec3: add and sub" {
    const V = Vec3(f32);
    const a = V.init(2.0, 3.0, 4.0);
    const b = V.init(1.0, 5.0, 7.0);

    const sum = a.add(b);
    try std.testing.expectEqual(@as(f32, 3.0), sum.x());
    try std.testing.expectEqual(@as(f32, 8.0), sum.y());
    try std.testing.expectEqual(@as(f32, 11.0), sum.z());

    const diff = a.sub(b);
    try std.testing.expectEqual(@as(f32, 1.0), diff.x());
    try std.testing.expectEqual(@as(f32, -2.0), diff.y());
    try std.testing.expectEqual(@as(f32, -3.0), diff.z());
}

test "Vec3: scalar arithmetic" {
    const V = Vec3(f32);
    const v = V.init(2.0, 4.0, 6.0);

    const add_s = v.addScalar(1.0);
    try std.testing.expectEqual(@as(f32, 3.0), add_s.x());
    try std.testing.expectEqual(@as(f32, 5.0), add_s.y());
    try std.testing.expectEqual(@as(f32, 7.0), add_s.z());

    const sub_s = v.subScalar(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), sub_s.x());
    try std.testing.expectEqual(@as(f32, 3.0), sub_s.y());
    try std.testing.expectEqual(@as(f32, 5.0), sub_s.z());

    const mul_s = v.mulScalar(2.0);
    try std.testing.expectEqual(@as(f32, 4.0), mul_s.x());
    try std.testing.expectEqual(@as(f32, 8.0), mul_s.y());
    try std.testing.expectEqual(@as(f32, 12.0), mul_s.z());

    const div_s = v.divScalar(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), div_s.x());
    try std.testing.expectEqual(@as(f32, 2.0), div_s.y());
    try std.testing.expectEqual(@as(f32, 3.0), div_s.z());
}

test "Vec3: length and distance" {
    const V = Vec3(f32);
    const a = V.init(1.0, 2.0, 2.0);
    const b = V.init(4.0, 6.0, 6.0);

    // len = sqrt(1² + 2² + 2²) = 3
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), a.len(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), a.lenSq(), 1e-6);

    // distance between (1,2,2) and (4,6,6) = sqrt(3² + 4² + 4²) = sqrt(41)
    const expected_distance = @as(f32, std.math.sqrt(41.0));
    try std.testing.expectApproxEqAbs(expected_distance, a.distance(b), 1e-6);
}

test "Vec3: abs and splat" {
    const V = Vec3(i32);
    const v = V.init(-3, 4, -5);
    const abs_v = v.abs();

    try std.testing.expectEqual(@as(i32, 3), abs_v.x());
    try std.testing.expectEqual(@as(i32, 4), abs_v.y());
    try std.testing.expectEqual(@as(i32, 5), abs_v.z());

    const s = V.splat(9);
    try std.testing.expectEqual(@as(i32, 9), s.x());
    try std.testing.expectEqual(@as(i32, 9), s.y());
    try std.testing.expectEqual(@as(i32, 9), s.z());
}

test "Vec3: ceil, divFloor, to" {
    const V = Vec3(f32);
    const v = V.init(1.2, 3.8, 4.1);
    const c = v.ceil();
    try std.testing.expectEqual(@as(f32, 2.0), c.x());
    try std.testing.expectEqual(@as(f32, 4.0), c.y());
    try std.testing.expectEqual(@as(f32, 5.0), c.z());

    const a = V.init(9.0, 10.0, 11.0);
    const b = V.init(2.0, 4.0, 5.0);
    const divf = a.divFloor(b);
    try std.testing.expectEqual(@as(f32, 4.0), divf.x());
    try std.testing.expectEqual(@as(f32, 2.0), divf.y());
    try std.testing.expectEqual(@as(f32, 2.0), divf.z());

    const to = v.to(f32);
    try std.testing.expectEqual(@as(f32, 1.2), to.x());
    try std.testing.expectEqual(@as(f32, 3.8), to.y());
    try std.testing.expectEqual(@as(f32, 4.1), to.z());
}

test "Vec3: cross product" {
    const V = Vec3(f32);
    const a = V.init(1.0, 0.0, 0.0);
    const b = V.init(0.0, 1.0, 0.0);
    const cross = a.cross(b);

    // (1,0,0) × (0,1,0) = (0,0,1)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cross.x(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cross.y(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cross.z(), 1e-6);
}

test "Vec3: swizzle" {
    const V = Vec3(f32);
    const v = V.init(1.0, 2.0, 3.0);
    const swz = v.swizzle(.z, .y, .x);

    try std.testing.expectEqual(@as(f32, 3.0), swz.x());
    try std.testing.expectEqual(@as(f32, 2.0), swz.y());
    try std.testing.expectEqual(@as(f32, 1.0), swz.z());
}

test "Vec4: initialization and components" {
    const V = Vec4(f32);
    const v = V.init(1.0, 2.0, 3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 1.0), v.x());
    try std.testing.expectEqual(@as(f32, 2.0), v.y());
    try std.testing.expectEqual(@as(f32, 3.0), v.z());
    try std.testing.expectEqual(@as(f32, 4.0), v.w());
}

test "Vec4: add and sub" {
    const V = Vec4(f32);
    const a = V.init(1.0, 2.0, 3.0, 4.0);
    const b = V.init(4.0, 3.0, 2.0, 1.0);

    const sum = a.add(b);
    try std.testing.expectEqual(@as(f32, 5.0), sum.x());
    try std.testing.expectEqual(@as(f32, 5.0), sum.y());
    try std.testing.expectEqual(@as(f32, 5.0), sum.z());
    try std.testing.expectEqual(@as(f32, 5.0), sum.w());

    const diff = a.sub(b);
    try std.testing.expectEqual(@as(f32, -3.0), diff.x());
    try std.testing.expectEqual(@as(f32, -1.0), diff.y());
    try std.testing.expectEqual(@as(f32, 1.0), diff.z());
    try std.testing.expectEqual(@as(f32, 3.0), diff.w());
}

test "Vec4: scalar arithmetic" {
    const V = Vec4(f32);
    const v = V.init(1.0, 2.0, 3.0, 4.0);

    const add_s = v.addScalar(1.0);
    try std.testing.expectEqual(@as(f32, 2.0), add_s.x());
    try std.testing.expectEqual(@as(f32, 3.0), add_s.y());
    try std.testing.expectEqual(@as(f32, 4.0), add_s.z());
    try std.testing.expectEqual(@as(f32, 5.0), add_s.w());

    const sub_s = v.subScalar(1.0);
    try std.testing.expectEqual(@as(f32, 0.0), sub_s.x());
    try std.testing.expectEqual(@as(f32, 1.0), sub_s.y());
    try std.testing.expectEqual(@as(f32, 2.0), sub_s.z());
    try std.testing.expectEqual(@as(f32, 3.0), sub_s.w());

    const mul_s = v.mulScalar(2.0);
    try std.testing.expectEqual(@as(f32, 2.0), mul_s.x());
    try std.testing.expectEqual(@as(f32, 4.0), mul_s.y());
    try std.testing.expectEqual(@as(f32, 6.0), mul_s.z());
    try std.testing.expectEqual(@as(f32, 8.0), mul_s.w());

    const div_s = v.divScalar(2.0);
    try std.testing.expectEqual(@as(f32, 0.5), div_s.x());
    try std.testing.expectEqual(@as(f32, 1.0), div_s.y());
    try std.testing.expectEqual(@as(f32, 1.5), div_s.z());
    try std.testing.expectEqual(@as(f32, 2.0), div_s.w());
}

test "Vec4: length and distance" {
    const V = Vec4(f32);
    const a = V.init(1.0, 2.0, 2.0, 1.0);
    const b = V.init(4.0, 6.0, 6.0, 3.0);

    // len = sqrt(1² + 2² + 2² + 1²) = sqrt(10) ≈ 3.1622777
    try std.testing.expectApproxEqAbs(@as(f32, std.math.sqrt(10.0)), a.len(), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), a.lenSq(), 1e-6);

    // distance = sqrt((3)² + (4)² + (4)² + (2)²) = sqrt(45) ≈ 6.708204
    const expected_dist = @as(f32, std.math.sqrt(45.0));
    try std.testing.expectApproxEqAbs(expected_dist, a.distance(b), 1e-6);
}

test "Vec4: abs and splat" {
    const V = Vec4(i32);
    const v = V.init(-1, 2, -3, 4);
    const abs_v = v.abs();

    try std.testing.expectEqual(@as(i32, 1), abs_v.x());
    try std.testing.expectEqual(@as(i32, 2), abs_v.y());
    try std.testing.expectEqual(@as(i32, 3), abs_v.z());
    try std.testing.expectEqual(@as(i32, 4), abs_v.w());

    const s = V.splat(9);
    try std.testing.expectEqual(@as(i32, 9), s.x());
    try std.testing.expectEqual(@as(i32, 9), s.y());
    try std.testing.expectEqual(@as(i32, 9), s.z());
    try std.testing.expectEqual(@as(i32, 9), s.w());
}

test "Vec4: ceil, divFloor, to" {
    const V = Vec4(f32);
    const v = V.init(1.2, 3.8, 4.1, 5.9);
    const c = v.ceil();
    try std.testing.expectEqual(@as(f32, 2.0), c.x());
    try std.testing.expectEqual(@as(f32, 4.0), c.y());
    try std.testing.expectEqual(@as(f32, 5.0), c.z());
    try std.testing.expectEqual(@as(f32, 6.0), c.w());

    const a = V.init(9.0, 10.0, 11.0, 12.0);
    const b = V.init(2.0, 4.0, 5.0, 6.0);
    const divf = a.divFloor(b);
    try std.testing.expectEqual(@as(f32, 4.0), divf.x());
    try std.testing.expectEqual(@as(f32, 2.0), divf.y());
    try std.testing.expectEqual(@as(f32, 2.0), divf.z());
    try std.testing.expectEqual(@as(f32, 2.0), divf.w());

    const to = v.to(f32);
    try std.testing.expectEqual(@as(f32, 1.2), to.x());
    try std.testing.expectEqual(@as(f32, 3.8), to.y());
    try std.testing.expectEqual(@as(f32, 4.1), to.z());
    try std.testing.expectEqual(@as(f32, 5.9), to.w());
}
