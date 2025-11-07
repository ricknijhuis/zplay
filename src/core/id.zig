const std = @import("std");

const Value = std.atomic.Value;

/// Returns an incremental unique identifier for the duration of the program for the specified type.
/// Each call to this function returns a value that is guaranteed to be different from all previous calls.
/// If called in same order it will return sequential values starting from 0.
pub fn Id(T: type) type {
    return enum(u32) {
        const Self = @This();
        pub const BaseT = T;

        var current: Value(u32) = .init(0);
        none = std.math.maxInt(u32),
        _,

        pub fn generate() Self {
            return @enumFromInt(current.fetchAdd(1, .seq_cst));
        }
    };
}

test "Id: generates unique incremental enum values per type" {
    const AId = Id(u8);
    const BId = Id(u16);

    // Test that the first call starts at 0
    try std.testing.expect(@intFromEnum(AId.generate()) == 0);
    try std.testing.expect(@intFromEnum(BId.generate()) == 0);

    // Test subsequent increments
    try std.testing.expect(@intFromEnum(AId.generate()) == 1);
    try std.testing.expect(@intFromEnum(AId.generate()) == 2);

    try std.testing.expect(@intFromEnum(BId.generate()) == 1);
    try std.testing.expect(@intFromEnum(BId.generate()) == 2);

    // Test that AId and BId maintain independent counters
    try std.testing.expect(@intFromEnum(AId.generate()) == 3);
    try std.testing.expect(@intFromEnum(BId.generate()) == 3);
}

test "Id: none has the maxInt value" {
    const AId = Id(u32);
    try std.testing.expect(@intFromEnum(AId.none) == std.math.maxInt(u32));
}
