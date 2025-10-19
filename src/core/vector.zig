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

        pub inline fn swizzle(self: *const Self, comptime comp_x: VecComponent, comptime comp_y: VecComponent, comptime comp_z: VecComponent) Self {
            return .{ .data = @shuffle(ScalarT, self.data, undefined, [3]ScalarT{
                @intFromEnum(comp_x),
                @intFromEnum(comp_y),
                @intFromEnum(comp_z),
            }) };
        }

        pub inline fn cross(self: Self, other: Self) Self {
            const s1 = self.swizzle(.y, .z, .x)
                .mul(&other.swizzle(.z, .x, .y));
            const s2 = self.swizzle(.z, .x, .y)
                .mul(&other.swizzle(.y, .z, .x));
            return s1.sub(&s2);
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
            return .{ .data = @abs(self.data) };
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
