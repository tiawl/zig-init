const std = @import("std");

var singleton: ?Root = null;

pub fn isInit() bool {
    return singleton != null;
}

pub fn init(allocator: std.mem.Allocator) !void {
    if (!isInit()) {
        singleton = undefined;
        try singleton.?.init(allocator);
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

    fn init(self: *@This(), allocator: std.mem.Allocator) !void {
        self.* = .{
            .__allocator = allocator,
        };
    }

    fn deinit(_: *@This()) void {
        return;
    }

    fn getAllocator(self: @This()) std.mem.Allocator {
        return self.__allocator;
    }
};
