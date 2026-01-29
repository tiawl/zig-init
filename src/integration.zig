const std = @import("std");
const build_options = @import("build_options");

const join = @import("utils").mem.join;

const front = @import("front");

const ArgIterator = front.ArgIterator;

const allocator = std.testing.allocator;

var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
var stderr = &stderr_writer.interface;
var tty_config: std.io.tty.Config = .escape_codes;

var it: ArgIterator = undefined;
var cli: []const u8 = undefined;

fn start(arena_allocator: std.mem.Allocator, comptime args: []const [:0]const u8) !void {
    cli = try join(allocator, " ", .{build_options.name} ++ args);
    try stderr.print("+++ \"{s}\" START\n", .{cli});
    try stderr.flush();
    it = ArgIterator.init(allocator, .{build_options.name} ++ args);
    try front.init(allocator, arena_allocator, &it);
}

fn ok() !void {
    front.deinit();
    it.deinit();
    try tty_config.setColor(stderr, .green);
    try stderr.print("+++ \"{s}\" OK\n", .{cli});
    try tty_config.setColor(stderr, .reset);
    try stderr.flush();
    allocator.free(cli);
}

fn renameMe(arena_allocator: std.mem.Allocator) !void {
    try start(arena_allocator, &.{});

    try front.instance().run();

    try ok();
}

test "success" {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    errdefer |err| {
        tty_config.setColor(stderr, .red) catch @panic("OOM");
        stderr.print("{s}\n", .{@errorName(err)}) catch @panic("OOM");
        tty_config.setColor(stderr, .reset) catch @panic("OOM");
        stderr.flush() catch @panic("OOM");
    }

    try renameMe(arena_allocator);
}

// TODO: add more integration tests
