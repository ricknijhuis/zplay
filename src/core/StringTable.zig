/// A string table to store all strings used in the application. Any function should accept String instead of []const u8.
/// Only allows for inserting not removing. Should not be used for very large strings that are short lived.
/// NOT THREAD SAFE!
const std = @import("std");
const mem = std.mem;
const hash_map = std.hash_map;
const testing = std.testing;

/// A string handle for use with the string table. Points to an index into the table
pub const String = enum(u32) {
    /// A zero length string
    empty,
    _,

    pub fn toOptional(value: String) OptionalString {
        return @enumFromInt(@intFromEnum(value));
    }
};

/// Optional string that can represent NULL.
pub const OptionalString = enum(u32) {
    /// A zero length string.
    empty,
    /// A NULL value.
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(i: OptionalString) ?String {
        if (i == .none) return null;
        return @enumFromInt(@intFromEnum(i));
    }
};

const StringTable = @This();

bytes: std.ArrayListUnmanaged(u8),
table: std.HashMapUnmanaged(
    u32,
    void,
    hash_map.StringIndexContext,
    hash_map.default_max_load_percentage,
),

pub const empty: StringTable = .{
    .bytes = .empty,
    .table = .empty,
};

pub fn getSlice(self: *const StringTable, handle: String) [:0]const u8 {
    const slice = self.bytes.items[@intFromEnum(handle)..];
    const end = mem.indexOfScalar(u8, slice, 0).?;
    return slice[0..end :0];
}

/// Gets the handle if exists.
/// If not exists makes sure there is enough size to hold it and retrns the handle
pub fn getOrPut(self: *StringTable, gpa: mem.Allocator, slice: []const u8) mem.Allocator.Error!String {
    try self.bytes.ensureUnusedCapacity(gpa, slice.len + 1);
    self.bytes.appendSliceAssumeCapacity(slice);
    // For efficiency we are using zero terminated strings, so append zero here.
    self.bytes.appendAssumeCapacity(0);
    return try self.getOrPutTrailingString(gpa, slice.len);
}

// Gets or puts from the map.
fn getOrPutTrailingString(self: *StringTable, gpa: mem.Allocator, len: usize) mem.Allocator.Error!String {
    const string_bytes = &self.bytes;
    const str_index: u32 = @intCast(string_bytes.items.len - len - 1);
    const key: []const u8 = string_bytes.items[str_index..][0..len :0];
    const gop = try self.table.getOrPutContextAdapted(gpa, key, std.hash_map.StringIndexAdapter{
        .bytes = string_bytes,
    }, std.hash_map.StringIndexContext{
        .bytes = string_bytes,
    });
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return @enumFromInt(gop.key_ptr.*);
    } else {
        gop.key_ptr.* = str_index;
        return @enumFromInt(str_index);
    }
}

pub fn deinit(self: *StringTable, gpa: mem.Allocator) void {
    self.bytes.deinit(gpa);
    self.table.deinit(gpa);
}

test "basic string insertion and retrieval" {
    const gpa = testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const hello: []const u8 = "hello";
    const world = "world";

    const str_hello = try table.getOrPut(gpa, hello);
    const str_hello_2 = try table.getOrPut(gpa, hello);
    try testing.expectEqual(str_hello, str_hello_2);

    const str_world = try table.getOrPut(gpa, world);
    try testing.expect(str_hello != str_world);
}

test "empty string handling" {
    const gpa = testing.allocator;
    var table: StringTable = .empty;

    defer table.deinit(gpa);

    const empty_str = "";
    const str_empty = try table.getOrPut(gpa, empty_str);
    try testing.expectEqual(@intFromEnum(str_empty), 0); // should be the first inserted (index 0)
}

test "optional string conversion" {
    const val = String.empty;
    const optional = val.toOptional();
    try testing.expect(optional != .none);
    try testing.expectEqual(optional.unwrap().?, val);

    const null_opt = OptionalString.none;
    try testing.expect(null_opt.unwrap() == null);
}

test "multiple unique strings" {
    const gpa = testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const strings = [_][]const u8{
        "zig", "is", "fun", "zig", "rocks", "is", "fun",
    };

    var indices: std.ArrayListUnmanaged(String) = .empty;
    defer indices.deinit(gpa);

    for (strings) |s| {
        const index = try table.getOrPut(gpa, s);
        try indices.append(gpa, index);
    }

    // Check duplicates match
    try testing.expectEqual(indices.items[0], indices.items[3]); // "zig"
    try testing.expectEqual(indices.items[1], indices.items[5]); // "is"
    try testing.expectEqual(indices.items[2], indices.items[6]); // "fun"

    // Check different strings get different indices
    try testing.expect(indices.items[0] != indices.items[1]); // "zig" != "is"
    try testing.expect(indices.items[4] != indices.items[0]); // "rocks" != "zig"
}

test "getSlice returns correct string content" {
    const gpa = std.testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const name = "zig";
    const handle = try table.getOrPut(gpa, name);
    const slice = table.getSlice(handle);

    try std.testing.expectEqualStrings(name, slice);
}

test "getSlice returns correct slice for multiple strings" {
    const gpa = std.testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const str1 = "hello";
    const str2 = "world";

    const h1 = try table.getOrPut(gpa, str1);
    const h2 = try table.getOrPut(gpa, str2);

    const s1 = table.getSlice(h1);
    const s2 = table.getSlice(h2);

    try std.testing.expectEqualStrings("hello", s1);
    try std.testing.expectEqualStrings("world", s2);
    try std.testing.expect(s1.ptr != s2.ptr); // should not alias
}

test "getSlice returns same slice for duplicate inserts" {
    const gpa = std.testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const data = "duplicate";

    const h1 = try table.getOrPut(gpa, data);
    const h2 = try table.getOrPut(gpa, data);

    try std.testing.expectEqual(h1, h2);

    const s1 = table.getSlice(h1);
    const s2 = table.getSlice(h2);

    try std.testing.expectEqualStrings(s1, s2);
    try std.testing.expect(s1.ptr == s2.ptr); // should alias the same memory
}

test "getSlice on empty string" {
    const gpa = std.testing.allocator;
    var table: StringTable = .empty;
    defer table.deinit(gpa);

    const h = try table.getOrPut(gpa, "");
    const slice = table.getSlice(h);

    try std.testing.expectEqualStrings("", slice);
    try std.testing.expectEqual(@intFromPtr(slice.ptr), @intFromPtr(&table.bytes.items[@intFromEnum(h)]));
}
