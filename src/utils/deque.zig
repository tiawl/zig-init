const std = @import("std");

// TODO: remove this file for the next Zig release

fn addOrOom(a: usize, b: usize) error{OutOfMemory}!usize {
    const result, const overflow = @addWithOverflow(a, b);
    if (overflow != 0) return error.OutOfMemory;
    return result;
}

pub fn Deque(comptime T: type) type {
    return struct {
        buffer: []T,
        head: usize,
        len: usize,

        pub const empty: @This() = .{
            .buffer = &.{},
            .head = 0,
            .len = 0,
        };

        pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
            gpa.free(self.buffer);
            self.* = undefined;
        }

        fn growCapacity(minimum: usize) usize {
            return minimum +| (minimum / 2 + @max(1, std.atomic.cache_line / @sizeOf(T)));
        }

        pub fn ensureTotalCapacity(self: *@This(), gpa: std.mem.Allocator, new_capacity: usize) std.mem.Allocator.Error!void {
            if (self.buffer.len >= new_capacity) return;
            return self.ensureTotalCapacityPrecise(gpa, growCapacity(new_capacity));
        }

        pub fn ensureTotalCapacityPrecise(self: *@This(), gpa: std.mem.Allocator, new_capacity: usize) std.mem.Allocator.Error!void {
            if (self.buffer.len >= new_capacity) return;
            const old_buffer = self.buffer;
            if (gpa.remap(old_buffer, new_capacity)) |new_buffer| {
                if (self.head > old_buffer.len - self.len) {
                    const head = new_buffer[self.head..old_buffer.len];
                    const tail = new_buffer[0 .. self.len - head.len];
                    if (head.len > tail.len and new_buffer.len - old_buffer.len > tail.len) {
                        @memcpy(new_buffer[old_buffer.len..][0..tail.len], tail);
                    } else {
                        self.head = new_buffer.len - head.len;
                        @memmove(new_buffer[self.head..][0..head.len], head);
                    }
                }
                self.buffer = new_buffer;
            } else {
                const new_buffer = try gpa.alloc(T, new_capacity);
                if (self.head < old_buffer.len - self.len) {
                    @memcpy(new_buffer[0..self.len], old_buffer[self.head..][0..self.len]);
                } else {
                    const head = old_buffer[self.head..];
                    const tail = old_buffer[0 .. self.len - head.len];
                    @memcpy(new_buffer[0..head.len], head);
                    @memcpy(new_buffer[head.len..][0..tail.len], tail);
                }
                self.head = 0;
                self.buffer = new_buffer;
                gpa.free(old_buffer);
            }
        }

        pub fn ensureUnusedCapacity(
            self: *@This(),
            gpa: std.mem.Allocator,
            additional_count: usize,
        ) std.mem.Allocator.Error!void {
            return self.ensureTotalCapacity(gpa, try addOrOom(self.len, additional_count));
        }

        pub fn pushBack(self: *@This(), gpa: std.mem.Allocator, item: T) error{OutOfMemory}!void {
            try self.ensureUnusedCapacity(gpa, 1);
            self.pushBackAssumeCapacity(item);
        }

        pub fn pushBackAssumeCapacity(self: *@This(), item: T) void {
            std.debug.assert(self.len < self.buffer.len);
            const buffer_index = self.bufferIndex(self.len);
            self.buffer[buffer_index] = item;
            self.len += 1;
        }

        pub fn front(self: *const @This()) ?T {
            if (self.len == 0) return null;
            return self.buffer[self.head];
        }

        pub fn popFront(self: *@This()) ?T {
            if (self.len == 0) return null;
            const pop_index = self.head;
            self.head = self.bufferIndex(1);
            self.len -= 1;
            return self.buffer[pop_index];
        }

        fn bufferIndex(self: *const @This(), i: usize) usize {
            const head_len = self.buffer.len - self.head;
            if (i < head_len) {
                return self.head + i;
            } else {
                return i - head_len;
            }
        }
    };
}
