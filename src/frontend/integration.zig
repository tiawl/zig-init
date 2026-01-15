const std = @import("std");

const recover = @import("recover");

const index = @import("index");
const TODO = index.TODO;

const ArgIterator = index.options.ArgIterator;

fn oops() noreturn {
    @panic("Oops");
}

test "success: TODO --standard-options --for-success" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        "TODO", // "--standard-options", "--for-success",
    });
    defer args.deinit();
    try TODO.init(allocator, &args);
    defer TODO.deinit();

    try TODO.instance().run();
}

test "success: TODO -V" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        "TODO", "-V",
    });
    defer args.deinit();
    try TODO.init(allocator, &args);
    defer TODO.deinit();

    try TODO.instance().run();
}

test "panic_before_init: TODO --panic-option --before-init" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        "TODO", //"--panic-option", "--before-init",
    });
    defer args.deinit();
    try std.testing.expectError(error.Panic, recover.call(oops, .{}));
}

test "panic_after_init: TODO --panic-option --after-init" {
    const allocator = std.testing.allocator;
    var args = ArgIterator.init(allocator, &[_][:0]const u8{
        "TODO", //"--panic-option", "--after-init",
    });
    defer args.deinit();
    try TODO.init(allocator, &args);
    defer TODO.deinit();
    try std.testing.expectError(error.Panic, recover.call(oops, .{}));
}

// TODO: add more integration tests
