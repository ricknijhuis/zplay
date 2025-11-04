const std = @import("std");

/// A fixed sized, circular ring buffer providing FIFO access.
/// When adding more elements than the size it will overwrite the oldest in the queue.
pub fn RingBuffer(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();
        buffer: [N]T,
        head: usize,
        tail: usize,

        /// A clean queue ready for use.
        pub const empty: Self = .{
            .buffer = undefined,
            .head = 0,
            .tail = 0,
        };

        /// Resets the queue
        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
        }

        /// Push a new item in the queue. If the queue is full it overrides the oldest element
        pub fn push(self: *Self, item: T) void {
            const next_tail = (self.tail + 1) % N;
            if (next_tail == self.head) {
                self.head = (self.head + 1) % N;
            }
            self.buffer[self.tail] = item;
            self.tail = next_tail;
        }

        /// Pop the oldest item. Returns `null` if buffer empty.
        pub fn pop(self: *Self) ?T {
            if (self.head == self.tail) {
                // buffer empty
                return null;
            }
            const val = self.buffer[self.head];
            self.head = (self.head + 1) % N;
            return val;
        }

        /// Peek at the oldest item without removing it. Returns `null` if empty.
        pub fn peek(self: *const Self) ?T {
            if (self.head == self.tail) return null;
            return self.buffer[self.head];
        }
    };
}

test "basic push/pop behavior" {
    var rb: RingBuffer(i32, 4) = .empty; // all fields have defaults

    // Push three (since N-1 usable)
    rb.push(1);
    try std.testing.expectEqual(1, rb.peek());

    rb.push(2);
    try std.testing.expectEqual(1, rb.peek());

    rb.push(3);
    try std.testing.expectEqual(1, rb.peek());

    // Overwrites oldest element.
    rb.push(4);
    try std.testing.expectEqual(2, rb.peek());

    // Pop in FIFO order
    try std.testing.expectEqual(2, rb.pop().?);
    try std.testing.expectEqual(3, rb.pop().?);
    try std.testing.expectEqual(4, rb.pop().?);
    // Now empty
    try std.testing.expect(rb.pop() == null);
}
