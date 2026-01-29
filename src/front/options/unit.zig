const std = @import("std");
const build_options = @import("build_options");

const join = @import("utils").mem.join;

const index = @import("index.zig");
const Options = index.Options;
const ArgIterator = index.ArgIterator;

const allocator = std.testing.allocator;

var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
var stderr = &stderr_writer.interface;
var tty_config: std.io.tty.Config = .escape_codes;

var opts: Options = undefined;
var it: ArgIterator = undefined;
var cli: []const u8 = undefined;

fn start(comptime args: []const [:0]const u8) !void {
    cli = try join(allocator, " ", .{build_options.name} ++ args);
    try stderr.print("+++ \"{s}\" ", .{cli});
    try stderr.flush();
    opts = try Options.init(allocator);
    it = ArgIterator.init(allocator, .{build_options.name} ++ args);
}

fn ok() !void {
    opts.deinit();
    it.deinit();
    allocator.free(cli);
    try tty_config.setColor(stderr, .green);
    try stderr.print("OK\n", .{});
    try tty_config.setColor(stderr, .reset);
    try stderr.flush();
}

fn noarg() !void {
    try start(&.{});

    try opts.parse(&it);
    try std.testing.expect(!opts.getHelp());
    try std.testing.expect(!opts.getVersion());

    try ok();
}

test "Options.parse" {
    errdefer |err| {
        tty_config.setColor(stderr, .red) catch @panic("OOM");
        stderr.print("{s}\n", .{@errorName(err)}) catch @panic("OOM");
        tty_config.setColor(stderr, .reset) catch @panic("OOM");
        stderr.flush() catch @panic("OOM");
    }

    try noarg();
    // TODO; add more test here
}
