const std = @import("std");

const utils = @import("utils");
const Deque = utils.Deque;

const FrontOptionsError = error{
    UnknownArgument,
};

fn enumTags(comptime T: type) []const u8 {
    const fields = @typeInfo(T).@"enum".fields;
    var result: [fields.len]u8 = undefined;
    for (&result, fields) |*r, f| r.* = f.value;
    const final = result;
    return &final;
}

fn short(comptime field: Opt) []const u8 {
    return "-" ++ std.fmt.comptimePrint("{c}", .{
        @intFromEnum(field),
    });
}

fn long(comptime field: Opt) []const u8 {
    return "--" ++ @tagName(field);
}

fn isUsed(comptime field: Opt, arg: [:0]const u8) bool {
    return std.mem.eql(u8, arg, short(field)) or std.mem.eql(u8, arg, long(field));
}

const Opt = @Type(.{
    .@"enum" = .{
        .tag_type = u8,
        .fields = @typeInfo(OptWith1Param).@"enum".fields ++ @typeInfo(OptWithoutParam).@"enum".fields,
        .decls = &.{},
        .is_exhaustive = false,
    },
});

const OptWith1Param = enum(u8) {
    const tags = enumTags(@This());

    fn is(str: []const u8) bool {
        inline for (@typeInfo(@This()).@"enum".fields) |field|
            if (std.mem.eql(u8, str, field.name[0..field.name.len])) return true;
        return false;
    }

    // TODO: add options here:
    // file = 'f',
};

const OptWithoutParam = enum(u8) {
    const tags = enumTags(@This());

    help = 'h',
    version = 'V',
};

pub const ArgIterator = struct {
    __allocator: std.mem.Allocator,
    __deque: Deque([:0]const u8),
    __args: []const [:0]const u8,
    __i: usize,

    pub fn init(allocator: std.mem.Allocator, args: []const [:0]const u8) @This() {
        return .{
            .__allocator = allocator,
            .__deque = .empty,
            .__args = args,
            .__i = 0,
        };
    }

    pub fn deinit(self: *@This()) void {
        while (self.getDeque().len > 0) self.popFront();
        self.ptrDeque().deinit(self.getAllocator());
    }

    fn getAllocator(self: @This()) std.mem.Allocator {
        return self.__allocator;
    }

    fn getDeque(self: @This()) Deque([:0]const u8) {
        return self.__deque;
    }

    fn ptrDeque(self: *@This()) *Deque([:0]const u8) {
        return &self.__deque;
    }

    fn getArgs(self: @This()) []const [:0]const u8 {
        return self.__args;
    }

    fn getArg(self: @This(), i: usize) [:0]const u8 {
        return self.getArgs()[i];
    }

    fn getI(self: @This()) usize {
        return self.__i;
    }

    fn ptrI(self: *@This()) *usize {
        return &self.__i;
    }

    fn incrI(self: *@This()) void {
        self.ptrI().* += 1;
    }

    fn popFront(self: *@This()) void {
        std.debug.assert(self.getDeque().len > 0);
        self.getAllocator().free(self.getDeque().front().?);
    }

    fn append(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        std.debug.assert(self.getDeque().len < 2);
        try self.ptrDeque().pushBack(self.getAllocator(), try std.fmt.allocPrintSentinel(self.getAllocator(), fmt, args, 0));
    }

    // Handle '-abc' the same as '-a -bc' for short-form no-arg options
    fn handleContractedShortOptWithoutParam(self: *@This()) !void {
        var arg = if (self.getDeque().len > 0) self.getDeque().front().? else self.getArg(self.getI());

        if (!std.mem.startsWith(u8, arg, "-") or arg.len <= 2 or std.mem.indexOfAny(u8, arg[1..], OptWithoutParam.tags) != 0) return;

        var allocated = false;
        defer if (allocated) self.getAllocator().free(arg);
        if (self.getDeque().len > 0) {
            arg = try self.getAllocator().dupeZ(u8, self.getDeque().front().?);
            allocated = true;
            self.popFront();
        }

        try self.append("{s}", .{
            arg[0..2],
        });
        try self.append("-{s}", .{
            arg[2..],
        });
    }

    // Handle '-foo' the same as '-f oo' for short-form 1-arg options
    fn handleContractedShortOptWith1Param(self: *@This()) !void {
        var arg = if (self.getDeque().len > 0) self.getDeque().front().? else self.getArg(self.getI());

        if (!std.mem.startsWith(u8, arg, "-") or arg.len <= 2 or std.mem.indexOfAny(u8, arg[1..], OptWith1Param.tags) != 0) return;

        var allocated = false;
        defer if (allocated) self.getAllocator().free(arg);
        if (self.getDeque().len > 0) {
            arg = try self.getAllocator().dupeZ(u8, self.getDeque().front().?);
            allocated = true;
            self.popFront();
        }

        try self.append("{s}", .{
            arg[0..2],
        });
        try self.append("{s}", .{
            arg[2..],
        });
    }

    // Handle '--file=file1' the same as '--file file1' for long-form 1-arg options
    fn handleEqualLongOptWith1Param(self: *@This()) !void {
        var arg = if (self.getDeque().len > 0) self.getDeque().front().? else self.getArg(self.getI());
        const equal_index = std.mem.indexOfScalar(u8, arg, '=');

        if (!std.mem.startsWith(u8, arg, "--") or arg.len <= 3 or equal_index == null or !OptWith1Param.is(arg[2..equal_index.?])) return;

        var allocated = false;
        defer if (allocated) self.getAllocator().free(arg);
        if (self.getDeque().len > 0) {
            arg = try self.getAllocator().dupeZ(u8, self.getDeque().front().?);
            allocated = true;
            self.popFront();
        }

        try self.append("{s}", .{
            arg[0..equal_index.?],
        });
        if (arg[equal_index.? + 1 ..].len > 0) try self.append("{s}", .{
            arg[equal_index.? + 1 ..],
        });
    }

    pub fn next(self: *@This()) !?[:0]const u8 {
        if (self.getDeque().len == 2) {
            self.popFront();
        } else if (self.getDeque().len == 1) {
            self.popFront();
            self.incrI();
        }

        if (self.getI() >= self.getArgs().len and self.getDeque().len == 0) return null;

        try self.handleContractedShortOptWithoutParam();
        if (self.getDeque().len < 2) try self.handleContractedShortOptWith1Param();
        if (self.getDeque().len < 2) try self.handleEqualLongOptWith1Param();

        if (self.getDeque().len > 0) {
            return self.getDeque().front().?;
        } else {
            defer self.incrI();
            return self.getArg(self.getI());
        }
    }
};

pub const Options = struct {
    __allocator: std.mem.Allocator,
    __help: bool,
    __version: bool,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .__allocator = allocator,
            .__help = false,
            .__version = false,
        };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    fn getAllocator(self: @This()) std.mem.Allocator {
        return self.__allocator;
    }

    pub fn getHelp(self: @This()) bool {
        return self.__help;
    }

    pub fn getVersion(self: @This()) bool {
        return self.__version;
    }

    fn needHelp(self: *@This()) void {
        self.__help = true;
    }

    fn needVersion(self: *@This()) void {
        self.__version = true;
    }

    pub fn parse(self: *@This(), it: *ArgIterator) !void {
        _ = try it.next();
        while (try it.next()) |arg| {
            if (isUsed(.help, arg)) {
                self.needHelp();
            } else if (isUsed(.version, arg)) {
                self.needVersion();
            } else return error.UnknownArgument;
        }
    }
};
