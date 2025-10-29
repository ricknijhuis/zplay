//! A container using sparse set to manage handles to items of type T.
//! Handles are generational and typesafe. The generation wrap around after max value is reached.
//! All items are stored in a single contiguous block of memory,
//! the sparse, dense and items slices provide pieces of that memory block. They are
//! placed in order of alignment.
//! NOT THREAD SAFE!
const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

const Allocator = mem.Allocator;
const Alignment = mem.Alignment;
const Error = Allocator.Error;

/// Handle used to index a specific HandleSet(T) using a handle for a HandleSet with a different T will
/// result in a compile error.
/// Max index value: 1,048,575
/// Max version value: 2048
fn HandleT(T: type) type {
    const RawT = packed struct(u32) {
        const Self = @This();

        index: u20,
        version: u12,

        /// Increments the version field, in case max version is achieved it will wrap arround
        pub inline fn update(self: Self) Self {
            self.version +%= 1;
        }

        /// Casts to int
        pub inline fn toInt(self: Self) u32 {
            return @bitCast(self);
        }

        /// Casts int to handle
        pub inline fn fromInt(raw: u32) Self {
            return @bitCast(raw);
        }

        /// Equality comparison using their integer representation
        pub inline fn eql(self: Self, other: Self) bool {
            return self.toInt() == other.toInt();
        }
    };

    return enum(u32) {
        const Self = @This();

        none = std.math.maxInt(u32),
        _,

        pub const Raw = RawT;

        /// The T type of the Sparse where this handle can be used for.
        pub const Item = T;

        pub inline fn toRaw(self: Self) RawT {
            return @bitCast(@intFromEnum(self));
        }

        pub inline fn fromRaw(self: RawT) Self {
            return @enumFromInt(@as(u32, @bitCast(self)));
        }

        pub fn toInt(self: Self) u32 {
            return @as(u32, @bitCast(self.toRaw()));
        }

        pub fn fromInt(value: u32) Self {
            return Self.fromRaw(RawT.fromInt(value));
        }

        pub inline fn init(index: u32, version: u32) Self {
            return .fromRaw(.{ .index = index, .version = version });
        }
    };
}

/// A basic sparse set enabling fast o(1) insert, removal and get.
/// Has the smallest memory footprint.
pub fn HandleSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const AlignmentOrder = enum {
            smallest,
            largest,
        };
        pub const Item = T;
        pub const Handle = HandleT(Self);
        pub const Field = meta.FieldEnum(Self);

        /// The sparse array containing the handles, might contain holes.
        /// if alignment of Handle and T are equal, sparse will contain the original allocated ptr.
        /// this allows for a single allocation for sparse, dense and items.
        sparse: []Handle.Raw,
        dense: []Handle.Raw,

        /// The items in a densly packed array. On removal the last item is moved to the hole and the index
        items: []Item,
        capacity: u32,
        next: u32,
        count: u32,

        pub const empty: Self = .{
            .sparse = &.{},
            .dense = &.{},
            .items = &.{},
            .capacity = 0,
            .next = 0,
            .count = 0,
        };

        const init_capacity = init: {
            var max = 1;
            const types: []const type = &.{ Item, Handle };
            for (types) |field| max = @as(comptime_int, @max(max, @sizeOf(field)));
            break :init @as(comptime_int, @max(1, std.atomic.cache_line / max));
        };

        const fields = std.meta.fields(Self)[0..3];

        /// `sizes.bytes` is an array of @sizeOf each T field. Sorted by alignment, descending.
        /// `sizes.fields` is an array mapping from `sizes.bytes` array index to field index.
        const sizes = blk: {
            const Data = struct {
                size: usize,
                size_index: usize,
                alignment: usize,
            };
            var data: [fields.len]Data = undefined;
            for (fields, 0..) |field_info, i| {
                data[i] = .{
                    .size = @sizeOf(std.meta.Child(field_info.type)),
                    .size_index = i,
                    .alignment = if (@sizeOf(std.meta.Child(field_info.type)) == 0) 1 else Alignment.of(std.meta.Child(field_info.type)).toByteUnits(),
                };
            }
            const Sort = struct {
                fn lessThan(context: void, lhs: Data, rhs: Data) bool {
                    _ = context;
                    return lhs.alignment > rhs.alignment;
                }
            };
            @setEvalBranchQuota(3 * fields.len * std.math.log2(fields.len));
            mem.sort(Data, &data, {}, Sort.lessThan);
            var sizes_bytes: [fields.len]usize = undefined;
            var field_indexes: [fields.len]usize = undefined;
            for (data, 0..) |elem, i| {
                sizes_bytes[i] = elem.size;
                field_indexes[i] = elem.size_index;
            }
            break :blk .{
                .bytes = sizes_bytes,
                .fields = field_indexes,
            };
        };

        const alignment: Alignment = .of(std.meta.Child(@FieldType(Self, fields[sizes.fields[0]].name)));

        /// Add one item to the list, grow capacity if needed. Returns the newly reserved index with uninitialized data.
        pub fn addOne(self: *Self, gpa: Allocator) Allocator.Error!Handle {
            try self.ensureUnusedCapacity(gpa, 1);
            return self.addOneAssumeCapacity();
        }

        /// Add one item to the list, grow capacity if needed but only exactly one. This can save memory and is usefull for smaller
        /// sets.
        pub fn addOneExact(self: *Self, gpa: Allocator) Allocator.Error!Handle {
            try self.ensureExactCapacity(gpa, self.count + 1);

            return self.addOneAssumeCapacity();
        }

        /// Add one item to the list, grow capacity if needed but only exactly one. This can save memory and is usefull for smaller
        /// sets.
        pub fn append(self: *Self, gpa: Allocator, item: Item) Allocator.Error!Handle {
            try self.ensureUnusedCapacity(gpa, 1);

            const handle = self.addOneAssumeCapacity();
            self.set(handle, item);

            return handle;
        }

        /// Add one item to the list, grow capacity if needed but only exactly one. This can save memory and is usefull for smaller
        /// sets.
        pub fn appendExact(self: *Self, gpa: Allocator, item: Item) Allocator.Error!Handle {
            try self.ensureExactCapacity(gpa, self.count + 1);

            const handle = self.addOneAssumeCapacity();
            self.set(handle, item);

            return handle;
        }

        /// Extend the list by 1 element, asserting `self.capacity`
        /// is sufficient to hold an additional item.  Returns the
        /// newly reserved index with uninitialized data.
        pub fn addOneAssumeCapacity(self: *Self) Handle {
            debug.assert(self.count < self.capacity);
            const index = self.next;
            const sparse_item: Handle.Raw = self.sparse[index];

            const sparse_handle: Handle.Raw = .{
                .index = @intCast(self.count),
                .version = sparse_item.version,
            };

            const dense_handle: Handle.Raw = .{
                .index = @intCast(index),
                .version = sparse_item.version,
            };

            self.next = @intCast(sparse_item.index);
            self.sparse[index] = sparse_handle;
            self.dense[sparse_handle.index] = dense_handle;
            self.count += 1;

            return .fromRaw(dense_handle);
        }

        /// Removes the given handle from the set, swapping it with the last element.
        pub fn swapRemove(self: *Self, handle: Handle) void {
            debug.assert(self.contains(handle));

            const raw = handle.toRaw();
            const dense_index = self.sparse[raw.index].index;
            // Update version, wrap around if needed
            const dense_version = self.sparse[raw.index].version +% 1;

            self.dense[dense_index].version = dense_version;
            self.sparse[raw.index] = .{
                .index = @intCast(self.next),
                .version = dense_version,
            };

            self.next = @intCast(raw.index);

            const last_index = self.count - 1;

            if (dense_index != last_index) {
                const last_dense = self.dense[last_index];
                self.items[dense_index] = self.items[last_index];
                self.dense[dense_index] = last_dense;
                self.sparse[last_dense.index].index = dense_index;
            }
            self.count -= 1;
        }

        pub fn set(self: *const Self, handle: Handle, item: Item) void {
            debug.assert(self.contains(handle));

            const sparse = self.sparse[handle.toRaw().index];

            self.items[sparse.index] = item;
        }

        pub fn getPtr(self: *const Self, handle: Handle) *Item {
            debug.assert(self.contains(handle));

            const sparse = self.sparse[handle.toRaw().index];

            return &self.items[sparse.index];
        }

        pub fn get(self: *const Self, handle: Handle) Item {
            debug.assert(self.contains(handle));

            const sparse = self.sparse[handle.toRaw().index];

            return self.items[sparse.index];
        }

        pub fn slice(self: *const Self) []Item {
            return self.items[0..self.count];
        }

        pub fn contains(self: *const Self, handle: Handle) bool {
            const raw = handle.toRaw();

            if (self.count < raw.index) return false;

            return (raw == self.dense[self.sparse[raw.index].index]);
        }

        pub fn ensureUnusedCapacity(self: *Self, gpa: Allocator, additional_count: usize) !void {
            return self.ensureTotalCapacity(gpa, self.count + additional_count);
        }

        pub fn ensureTotalCapacity(self: *Self, gpa: Allocator, new_capacity: usize) Allocator.Error!void {
            if (self.capacity >= new_capacity) return;
            return self.setCapacity(gpa, growCapacity(self.capacity, new_capacity));
        }

        pub fn ensureExactCapacity(self: *Self, gpa: Allocator, new_capacity: usize) Allocator.Error!void {
            if (self.capacity >= new_capacity) return;
            return self.setCapacity(gpa, new_capacity);
        }

        pub fn setCapacity(self: *Self, gpa: Allocator, new_capacity: usize) !void {
            debug.assert(new_capacity >= self.count);

            const new_bytes = try gpa.alignedAlloc(u8, alignment, capacityInBytes(new_capacity));
            const old_capacity: usize = self.capacity;
            var offset: usize = 0;
            if (self.count == 0) {
                gpa.free(self.allocatedBytes());
                inline for (sizes.fields) |i| {
                    @field(self, fields[i].name) = @as([*]FieldType(@enumFromInt(i)), @ptrCast(@alignCast(new_bytes.ptr + offset)))[0..new_capacity];
                    offset += new_capacity * @sizeOf(FieldType(@enumFromInt(i)));
                }
                self.capacity = @intCast(new_capacity);
            } else {
                var other: Self = .{
                    .sparse = &.{},
                    .dense = &.{},
                    .items = &.{},
                    .capacity = @intCast(new_capacity),
                    .count = self.count,
                    .next = self.count,
                };

                // memcpy everything in one go, is this safe with a sparse set?

                inline for (sizes.fields) |i| {
                    @field(other, fields[i].name) = @as([*]FieldType(@enumFromInt(i)), @ptrCast(@alignCast(new_bytes.ptr + offset)))[0..new_capacity];
                    offset += new_capacity * @sizeOf(FieldType(@enumFromInt(i)));
                }
                @memcpy(other.sparse[0..old_capacity], self.sparse);
                @memcpy(other.dense[0..self.count], self.dense);
                @memcpy(other.items[0..self.count], self.items);

                gpa.free(self.allocatedBytes());
                self.* = other;
            }

            for (old_capacity..self.capacity) |i| {
                self.sparse[i] = .fromInt(@intCast(i + 1));
            }
            self.sparse[self.capacity - 1].index = 0;
        }

        fn growCapacity(current: usize, minimum: usize) usize {
            var new = current;
            while (true) {
                new +|= new / 2 + init_capacity;
                if (new >= minimum)
                    return new;
            }
        }

        pub fn clear(self: *Self) void {
            for (self.sparse[0..self.capacity], 0..) |*entry, i| {
                entry.version +%= 1;
                entry.index = @intCast(i + 1);
            }
            if (self.capacity > 0) {
                self.sparse[self.capacity - 1].index = 0;
            }
            self.count = 0;
            self.next = 0;
        }

        pub fn handles(self: *const Self) []Handle {
            return @as([*]Handle, @ptrCast(@alignCast(self.dense.ptr)))[0..self.dense.len];
        }

        /// Utility function to cast the handles to a different type, this allows for wrapping
        /// the handle in a struct that can contain it's own set of functions.
        pub fn handlesTo(self: *const Self, NewT: type) []NewT {
            comptime debug.assert(@sizeOf(Handle) == @sizeOf(NewT));
            comptime debug.assert(@alignOf(Handle) == @alignOf(NewT));
            return @as([*]NewT, @ptrCast(@alignCast(self.dense.ptr)))[0..self.dense.len];
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            gpa.free(self.allocatedBytes());
            self.* = .empty;
        }

        // // Returns the actual allocated slice, created from combining the sparse and item slices
        fn allocatedBytes(self: *const Self) []align(alignment.toByteUnits()) u8 {
            const total_size = capacityInBytes(self.capacity);
            return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@field(self, fields[sizes.fields[0]].name).ptr))[0..total_size];
        }

        fn FieldType(comptime field: Field) type {
            return meta.Child(@FieldType(Self, @tagName(field)));
        }

        fn capacityInBytes(capacity: usize) usize {
            comptime var elem_bytes: usize = 0;
            inline for (sizes.bytes) |size| elem_bytes += size;
            return capacity * elem_bytes;
        }
    };
}

test "Can allocate multiple handles where aligment item is larger than handle" {
    const TestT = struct {
        foo: u64 = 0,
    };

    const allocator = testing.allocator;
    var sparse: HandleSet(TestT) = .empty;
    defer sparse.deinit(allocator);

    var handles: [32]HandleSet(TestT).Handle = undefined;

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    try testing.expectEqual(sparse.sparse.len, sparse.dense.len);
    try testing.expectEqual(sparse.sparse.len, sparse.items.len);
    try testing.expectEqual(32, sparse.count);

    for (handles, 0..) |handle, i| {
        try testing.expectEqual(@as(HandleSet(TestT).Handle, @enumFromInt(i)), handle);
    }
}

test "Can allocate multiple handles where alignment item is equal to handle" {
    const TestT = struct {
        foo: u32 = 0,
    };

    const allocator = testing.allocator;
    var sparse: HandleSet(TestT) = .empty;
    defer sparse.deinit(allocator);

    var handles: [32]HandleSet(TestT).Handle = undefined;

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    try testing.expectEqual(sparse.sparse.len, sparse.dense.len);
    try testing.expectEqual(sparse.sparse.len, sparse.items.len);
    try testing.expectEqual(32, sparse.count);

    for (handles, 0..) |handle, i| {
        try testing.expectEqual(@as(HandleSet(TestT).Handle, @enumFromInt(i)), handle);
    }
}

test "Can allocate multiple handles where alignment item is smaller than handle" {
    const TestT = struct {
        foo: u8 = 0,
    };

    const allocator = testing.allocator;
    var sparse: HandleSet(TestT) = .empty;
    defer sparse.deinit(allocator);

    var handles: [32]HandleSet(TestT).Handle = undefined;

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    try testing.expectEqual(sparse.sparse.len, sparse.dense.len);
    try testing.expectEqual(sparse.sparse.len, sparse.items.len);
    try testing.expectEqual(32, sparse.count);

    for (handles, 0..) |handle, i| {
        try testing.expectEqual(@as(HandleSet(TestT).Handle, @enumFromInt(i)), handle);
    }
}

test "Handle becomes unavailable after remove" {
    const TestT = struct {
        foo: u64 = 0,
    };

    const allocator = testing.allocator;
    var sparse: HandleSet(TestT) = .empty;
    defer sparse.deinit(allocator);

    const count = 32;
    var handles: [count]HandleSet(TestT).Handle = undefined;

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    try testing.expectEqual(sparse.sparse.len, sparse.dense.len);
    try testing.expectEqual(sparse.sparse.len, sparse.items.len);
    try testing.expectEqual(count, sparse.count);

    for (handles, 0..) |handle, i| {
        try testing.expectEqual(@as(HandleSet(TestT).Handle, @enumFromInt(i)), handle);
    }

    const rem = 6;
    try testing.expectEqual(true, sparse.contains(handles[rem]));
    sparse.swapRemove(handles[rem]);
    try testing.expectEqual(false, sparse.contains(handles[rem]));

    const rem1 = 9;
    try testing.expectEqual(true, sparse.contains(handles[rem1]));
    sparse.swapRemove(handles[rem1]);
    try testing.expectEqual(false, sparse.contains(handles[rem1]));

    try testing.expectEqual(count - 2, sparse.count);
}

test "clear invalidates current handles and starts again at index 0" {
    const TestT = struct {
        foo: u32 = 0,
    };

    const allocator = testing.allocator;
    var sparse: HandleSet(TestT) = .empty;
    defer sparse.deinit(allocator);

    var handles: [32]HandleSet(TestT).Handle = undefined;

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    try testing.expectEqual(sparse.sparse.len, sparse.dense.len);
    try testing.expectEqual(sparse.sparse.len, sparse.items.len);
    try testing.expectEqual(32, sparse.count);

    sparse.clear();

    try testing.expectEqual(sparse.count, 0);
    try testing.expectEqual(sparse.capacity, 32);

    for (handles) |handle| {
        try testing.expectEqual(false, sparse.contains(handle));
    }

    for (0..handles.len) |i| {
        handles[i] = try sparse.addOne(allocator);
    }

    for (handles) |handle| {
        try testing.expect(sparse.contains(handle));
    }
}
