const std = @import("std");

pub const enums = struct {
    pub fn greatest(comptime Enum: type) Enum {
        return comptime blk: {
            const enum_info = @typeInfo(Enum).@"enum";
            if (enum_info.fields.len == 0) {
                @compileError("enum has no fields");
            }

            var max_value: enum_info.tag_type = enum_info.fields[0].value;

            for (enum_info.fields[1..]) |field| {
                max_value = @max(max_value, field.value);
            }

            break :blk @enumFromInt(max_value);
        };
    }
};

test "enums: greatest returns for exhaustive enum" {
    const MyEnum = enum(u8) {
        a = 1,
        b = 3,
        c = 2,
    };

    const greatest_value = enums.greatest(MyEnum);
    try std.testing.expect(greatest_value == MyEnum.b);
}

test "enums: greatest returns for non exhaustive enum" {
    const MyEnum = enum(u8) {
        a = 1,
        b = 3,
        c = 2,
        _,
    };

    const greatest_value = enums.greatest(MyEnum);
    try std.testing.expect(greatest_value == MyEnum.b);
}
