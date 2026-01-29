const std = @import("std");

// modified std.mem.join to add double single-quotes for empty strings
pub fn join(allocator: std.mem.Allocator, separator: []const u8, slices: []const []const u8) std.mem.Allocator.Error![]u8 {
    if (slices.len == 0) return &[0]u8{};

    const total_len = blk: {
        var sum: usize = separator.len * (slices.len - 1);
        for (slices) |slice| {
            if (slice.len > 0) sum += slice.len else sum += 2;
        }
        break :blk sum;
    };

    const buf = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buf);

    @memcpy(buf[0..slices[0].len], slices[0]);
    var buf_index: usize = slices[0].len;
    for (slices[1..]) |slice| {
        @memcpy(buf[buf_index .. buf_index + separator.len], separator);
        buf_index += separator.len;
        if (slice.len > 0) {
            @memcpy(buf[buf_index .. buf_index + slice.len], slice);
            buf_index += slice.len;
        } else {
            @memcpy(buf[buf_index .. buf_index + 2], "''");
            buf_index += 2;
        }
    }

    // No need for shrink since buf is exactly the correct size.
    return buf;
}

pub fn trim(slice: []const u8) []const u8 {
    return std.mem.trim(u8, slice, &std.ascii.whitespace);
}
