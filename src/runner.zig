const std = @import("std");
const builtin = @import("builtin");

const Status = enum {
    ok,
    fail,
    skip,
    leak,
    text,

    fn color(self: @This()) std.io.tty.Color {
        return switch (self) {
            .ok => .green,
            .fail => .red,
            .leak => .yellow,
            .skip => .cyan,
            else => .reset,
        };
    }
};

const Printer = struct {
    __buffer: [1024]u8 = undefined,
    __file_writer: std.fs.File.Writer = undefined,
    __tty_conf: std.io.tty.Config = .escape_codes,

    fn init(self: *@This()) void {
        self.setFileWriter(std.fs.File.stderr().writer(self.ptrBuffer()));
    }

    fn ptrBuffer(self: *@This()) *[1024]u8 {
        return &self.__buffer;
    }

    fn ptrFileWriter(self: *@This()) *std.fs.File.Writer {
        return &self.__file_writer;
    }

    fn setFileWriter(self: *@This(), file_writer: std.fs.File.Writer) void {
        self.ptrFileWriter().* = file_writer;
    }

    fn getTTYConf(self: @This()) std.io.tty.Config {
        return self.__tty_conf;
    }

    fn print(self: *@This(), status: Status, comptime format: []const u8, args: anytype) !void {
        const writer = &self.ptrFileWriter().interface;
        try self.getTTYConf().setColor(writer, status.color());
        try writer.print(format ++ "\n", args);
        try self.getTTYConf().setColor(writer, .reset);
        try writer.flush();
    }
};

pub fn main() !void {
    var printer: Printer = .{};
    printer.init();

    var buffer: [64]u8 = undefined;

    var ok: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;

    for (builtin.test_functions) |func| {
        std.testing.allocator_instance = .{};
        var status: Status = .ok;

        try printer.print(.text, "+ {s}: START", .{
            func.name,
        });

        const result = func.func();

        if (std.testing.allocator_instance.deinit() == .leak) {
            status = .leak;
            leak += 1;
        } else if (result) |_| {
            ok += 1;
        } else |err| {
            switch (err) {
                error.SkipZigTest => {
                    status = .skip;
                    skip += 1;
                },
                else => {
                    status = .fail;
                    fail += 1;
                    try printer.print(status, "+ {s}: {s}", .{
                        func.name, @errorName(err),
                    });
                    if (@errorReturnTrace()) |trace| std.debug.dumpStackTrace(trace.*);
                    continue;
                },
            }
        }
        try printer.print(status, "+ {s}: {s}", .{
            func.name, std.ascii.upperString(&buffer, @tagName(status)),
        });
    }

    const total = ok + fail + skip + leak;
    try printer.print(.text, "*" ** 80 ++ "\nFor {d} test{s}:", .{
        total, if (total > 1) "s" else "",
    });
    try printer.print(.ok, "- {d} test{s} succeded", .{
        ok, if (ok > 1) "s" else "",
    });
    try printer.print(.fail, "- {d} test{s} failed", .{
        fail, if (fail > 1) "s" else "",
    });
    try printer.print(.leak, "- {d} test{s} leaked", .{
        leak, if (leak > 1) "s" else "",
    });
    try printer.print(.skip, "- {d} test{s} skipped", .{
        skip, if (skip > 1) "s" else "",
    });
    try printer.print(.text, "*" ** 80, .{});
}
