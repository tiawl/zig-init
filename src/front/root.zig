const std = @import("std");

const build_options = @import("build_options");
const back = @import("back");

const index = @import("index.zig");

const OptionsParser = index.OptionsParser;
const ArgIterator = index.ArgIterator;

var singleton: ?Root = null;

pub fn isInit() bool {
    return singleton != null;
}

pub fn init(allocator: std.mem.Allocator, arena_allocator: std.mem.Allocator, args: *ArgIterator) !void {
    if (!isInit()) {
        singleton = undefined;
        try singleton.?.init(allocator, arena_allocator, args);
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
    __arena_allocator: std.mem.Allocator,
    __options_parser: OptionsParser,

    fn init(self: *@This(), allocator: std.mem.Allocator, arena_allocator: std.mem.Allocator, args: *ArgIterator) !void {
        self.* = .{
            .__allocator = allocator,
            .__arena_allocator = arena_allocator,
            .__options_parser = undefined,
        };

        self.setOptionsParser(try OptionsParser.init(allocator));
        errdefer self.ptrOptionsParser().deinit();

        self.ptrOptionsParser().parse(args) catch |err| {
            try self.help();
            return err;
        };
    }

    fn deinit(self: *@This()) void {
        self.ptrOptionsParser().deinit();
        back.deinit();
    }

    fn getAllocator(self: @This()) std.mem.Allocator {
        return self.__allocator;
    }

    fn getArenaAllocator(self: @This()) std.mem.Allocator {
        return self.__arena_allocator;
    }

    fn getOptionsParser(self: @This()) OptionsParser {
        return self.__options_parser;
    }

    fn ptrOptionsParser(self: *@This()) *OptionsParser {
        return &self.__options_parser;
    }

    fn setOptionsParser(self: *@This(), options_parser: OptionsParser) void {
        self.ptrOptionsParser().* = options_parser;
    }

    fn help(self: @This()) std.mem.Allocator.Error!void {
        std.debug.print(
            \\{s}
            \\
            \\Usage:
            \\    {s} [options]
            \\
            \\Options:
            \\
            , .{
                build_options.description, build_options.name,
            });
       try self.getOptionsParser().printHelp();
    }

    fn version() void {
        std.debug.print("{s} {s}\n", .{
            build_options.name, build_options.version,
        });
    }

    pub fn run(self: *@This()) !void {
        try back.init(self.getAllocator());
        errdefer back.deinit();

        if (self.getOptionsParser().getVersion()) {
            version();
            if (!self.getOptionsParser().getHelp()) return;
        }

        if (self.getOptionsParser().getHelp()) {
            try self.help();
            return;
        }
    }
};
