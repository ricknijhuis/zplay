pub fn fieldCountOfType(comptime T: type, ValueT: type) usize {
    const ti = @typeInfo(ValueT);
    switch (ti) {
        .@"struct" => |s| {
            // Count matching fields
            comptime var count: usize = 0;
            inline for (s.fields) |f| {
                if (f.type == T) count += 1;
            }
            return count;
        },
        else => @compileError("Expected a tuple or struct"),
    }
}

pub fn fieldsOfType(comptime T: type, value: anytype, buffer: []T) []T {
    const ti = @typeInfo(@TypeOf(value));
    switch (ti) {
        inline .@"struct" => |s| {
            inline for (s.fields, 0..) |f, i| {
                if (f.type == T) {
                    buffer[i] = @field(value, f.name);
                }
            }
        },
        else => @compileError("Expected a tuple or struct"),
    }
}
