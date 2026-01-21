const std = @import("std");
const recover = @import("recover");

const index = @import("index.zig");

const Options = index.Options;
const ArgIterator = index.ArgIterator;

test "Options.parse: TODO" {
    const allocator = std.testing.allocator;

    var opts = try Options.init(allocator);
    defer opts.deinit();

    var it = ArgIterator.init(allocator, &[_][:0]const u8{
        "TODO",
    });
    defer it.deinit();

    try opts.parse(&it);
    // TODO: add more testing Options here
}

// TODO: add more tests here
