const std = @import("std");

const build_options = @import("build_options");
const back = @import("back");

const index = @import("index.zig");

const Options = index.Options;
const ArgIterator = index.ArgIterator;

var singleton: ?Root = null;

pub fn isInit() bool {
    return singleton != null;
}

pub fn init(allocator: std.mem.Allocator, args: *ArgIterator) !void {
    if (!isInit()) {
        singleton = undefined;
        try singleton.?.init(allocator, args);
    }
}

pub fn deinit() void {
    if (singleton) |*root| root.deinit();
    singleton = null;
}

pub fn instance() *Root {
    return if (singleton) |*root| root else unreachable;
}

const Root = struct {
    __allocator: std.mem.Allocator,
    __opts: Options,

    fn init(self: *@This(), allocator: std.mem.Allocator, args: *ArgIterator) !void {
        self.* = .{
            .__allocator = allocator,
            .__opts = undefined,
        };

        self.setOpts(try Options.init(allocator));
        errdefer self.ptrOpts().deinit();

        try self.ptrOpts().parse(args);
    }

    fn deinit(self: *@This()) void {
        self.ptrOpts().deinit();
        back.deinit();
    }

    fn getAllocator(self: @This()) std.mem.Allocator {
        return self.__allocator;
    }

    fn getOpts(self: @This()) Options {
        return self.__opts;
    }

    fn ptrOpts(self: *@This()) *Options {
        return &self.__opts;
    }

    fn setOpts(self: *@This(), opts: Options) void {
        self.ptrOpts().* = opts;
    }

    fn help() void {
        std.debug.print("TODO\n", .{});
    }

    fn version() void {
        std.debug.print("TODO %s\n", .{
            build_options.version,
        });
    }

    pub fn run(self: *@This()) !void {
        try back.init(self.getAllocator());
        errdefer back.deinit();

        std.debug.print("TODO\n", .{});
    }
};
