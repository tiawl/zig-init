const std = @import("std");
const build_options = @import("build_options");

const recover = @import("recover");

const front = @import("front");

const ArgIterator = front.ArgIterator;

fn oops() noreturn {
    @panic("Oops");
}

test "success: TODO --standard-options --for-success" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        build_options.name, // "--standard-options", "--for-success",
    });
    defer args.deinit();
    try front.init(allocator, &args);
    defer front.deinit();

    try front.instance().run();
}

test "success: TODO -V" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        build_options.name, "-V",
    });
    defer args.deinit();
    try front.init(allocator, &args);
    defer front.deinit();

    try front.instance().run();
}

test "panic_before_init: TODO --panic-option --before-init" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        build_options.name, //"--panic-option", "--before-init",
    });
    defer args.deinit();
    try std.testing.expectError(error.Panic, recover.call(oops, .{}));
}

test "panic_after_init: TODO --panic-option --after-init" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        build_options.name, //"--panic-option", "--after-init",
    });
    defer args.deinit();
    try front.init(allocator, &args);
    defer front.deinit();
    try std.testing.expectError(error.Panic, recover.call(oops, .{}));
}

// TODO: add more integration tests
