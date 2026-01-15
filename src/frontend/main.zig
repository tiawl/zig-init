const std = @import("std");
const builtin = @import("builtin");

const index = @import("index.zig");
const TODO = index.TODO;

const options = index.options;
const ArgIterator = options.ArgIterator;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() void {
    const allocator, const is_debug = gpa: {
        if (builtin.os.tag == .wasi) break :gpa .{
            std.heap.wasm_allocator,
            false,
        };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{
                debug_allocator.allocator(),
                true,
            },
            .ReleaseFast, .ReleaseSmall => .{
                std.heap.smp_allocator,
                false,
            },
        };
    };
    defer {
        if (is_debug) {
            if (debug_allocator.deinit() == .leak) {
                std.debug.print("Memory Leak\n", .{});
                std.process.exit(1);
            }
        }
    }

    const args = std.process.argsAlloc(allocator) catch |err| {
        std.debug.print("Failed to process command line arguments: {s}\n", .{
            @errorName(err),
        });
        std.process.exit(1);
    };
    defer std.process.argsFree(allocator, args);
    var it = ArgIterator.init(allocator, args);
    defer it.deinit();

    TODO.init(allocator, &it) catch |err| {
        std.debug.print("Failed to init: {s}\n", .{
            @errorName(err),
        });
        std.process.exit(1);
    };
    defer TODO.deinit();

    TODO.instance().run() catch |err| {
        std.debug.print("Failed to run: {s}\n", .{
            @errorName(err),
        });
        std.process.exit(1);
    };
}
