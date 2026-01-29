const std = @import("std");
const zon = @import("build.zig.zon");

const TestSteps = struct {
    unit_test_step: *std.Build.Step,
    integration_test_step: *std.Build.Step,
};

fn buildOptions(builder: *std.Build) !*std.Build.Module {
    const options = builder.addOptions();

    var code: u8 = undefined;
    const git = builder.findProgram(&.{
        "git",
    }, &.{}) catch |err| switch (err) {
        error.FileNotFound => "git",
        else => return err,
    };
    const raw_git_describe = builder.runAllowFail(&[_][]const u8{
        git,     "-C",     builder.build_root.path orelse ".", "--git-dir", ".git",
        "describe", "--match", "*.*.*", "--tags", "--abbrev=9",
    }, &code, .Ignore) catch zon.version;
    const git_describe = std.mem.trim(u8, raw_git_describe, " \n\r");

    var it = std.mem.splitScalar(u8, git_describe, '.');
    const sem_breaking = it.next().?;
    const sem_feature = it.next().?;
    _ = try std.fmt.parseUnsigned(u32, sem_breaking, 10);
    _ = try std.fmt.parseUnsigned(u32, sem_feature, 10);

    const sem_patch = switch (std.mem.count(u8, git_describe, "-")) {
        // Tagged commit
        0 => it.next().?,
        // Untagged commit
        2 => blk: {
            it = std.mem.splitScalar(u8, git_describe, '-');
            const tagged_ancestor = it.first();
            const commit_height = it.next().?;
            const commit_id = it.next().?;

            const sem_version = try std.SemanticVersion.parse(builder.fmt("{s}.{s}.0", .{
                sem_breaking, sem_feature,
            }));
            const ancestor_version = try std.SemanticVersion.parse(tagged_ancestor);
            if (sem_version.order(ancestor_version) != .eq) {
                std.debug.print("Semantic version '{}.{}.{}' must be equal to tagged ancestor '{}.{}.{}'\n", .{
                    sem_version.major, sem_version.minor, sem_version.patch, ancestor_version.major, ancestor_version.minor, ancestor_version.patch,
                });
                std.process.exit(1);
            }

            // Check that the commit hash is prefixed with a 'g' (a Git convention).
            if (commit_id.len < 1 or commit_id[0] != 'g') {
                std.debug.print("Unexpected `git describe` output: {s}\n", .{
                    git_describe,
                });
                std.process.exit(1);
            }

            _ = try std.fmt.parseUnsigned(u32, commit_height, 10);
            break :blk builder.fmt("{s}+{s}", .{
                commit_height, commit_id[1..],
            });
        },
        else => {
            std.debug.print("Unexpected `git describe` output: {s}\n", .{
                git_describe,
            });
            std.process.exit(1);
        },
    };
    const version = builder.fmt("{s}.{s}.{s}", .{
        sem_breaking, sem_feature, sem_patch,
    });
    options.addOption([:0]const u8, "name", @tagName(zon.name));
    options.addOption([:0]const u8, "version", try builder.allocator.dupeZ(u8, version));
    return options.createModule();
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const build_options = try buildOptions(builder);

    const utils = builder.createModule(.{
        .root_source_file = .{
            .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                "src", "utils", "index.zig",
            }),
        },
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    var back = builder.addModule("back", .{
        .root_source_file = .{
            .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                "src", "back", "index.zig",
            }),
        },
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "build_options",
                .module = build_options,
            },
            .{
                .name = "utils",
                .module = utils,
            },
        },
    });

    const front = builder.createModule(.{
        .root_source_file = .{
            .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                "src", "front", "index.zig",
            }),
        },
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "build_options",
                .module = build_options,
            },
            .{
                .name = "back",
                .module = back,
            },
            .{
                .name = "utils",
                .module = utils,
            },
        },
    });

    const exe = builder.addExecutable(.{
        .name = @tagName(zon.name),
        .root_module = builder.createModule(.{
            .root_source_file = .{
                .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                    "src", "main.zig",
                }),
            },
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "build_options",
                    .module = build_options,
                },
                .{
                    .name = "front",
                    .module = front,
                },
                .{
                    .name = "utils",
                    .module = utils,
                },
            },
        }),
    });

    builder.installArtifact(exe);

    const test_steps: TestSteps = steps: {
        const unit_test_step = step: {
            const back_unit_tests = builder.addTest(.{
                .test_runner = .{
                    .path = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "runner.zig",
                        }),
                    },
                    .mode = .simple,
                },
                .root_module = builder.createModule(.{
                    .root_source_file = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "back", "unit.zig",
                        }),
                    },
                    .target = target,
                    .optimize = .Debug,
                }),
            });
            for (back.import_table.keys(), back.import_table.values()) |name, module|
                back_unit_tests.root_module.addImport(name, module);

            back_unit_tests.step.dependOn(builder.getInstallStep());

            const back_unit_tests_runner = builder.addRunArtifact(back_unit_tests);

            const front_unit_tests = builder.addTest(.{
                .test_runner = .{
                    .path = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "runner.zig",
                        }),
                    },
                    .mode = .simple,
                },
                .root_module = builder.createModule(.{
                    .root_source_file = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "front", "unit.zig",
                        }),
                    },
                    .target = target,
                    .optimize = .Debug,
                }),
            });
            for (front.import_table.keys(), front.import_table.values()) |name, module|
                front_unit_tests.root_module.addImport(name, module);

            front_unit_tests.step.dependOn(builder.getInstallStep());

            const front_unit_tests_runner = builder.addRunArtifact(front_unit_tests);

            const unit_test_step = builder.step("test-unit", "Run unit tests");
            unit_test_step.dependOn(&back_unit_tests_runner.step);
            unit_test_step.dependOn(&front_unit_tests_runner.step);

            break :step unit_test_step;
        };

        const integration_test_step = step: {
            const integration_tests = builder.addTest(.{
                .test_runner = .{
                    .path = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "runner.zig",
                        }),
                    },
                    .mode = .simple,
                },
                .root_module = builder.createModule(.{
                    .root_source_file = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            "src", "integration.zig",
                        }),
                    },
                    .target = target,
                    .optimize = .Debug,
                }),
            });

            for (exe.root_module.import_table.keys(), exe.root_module.import_table.values()) |name, module|
                integration_tests.root_module.addImport(name, module);

            const integration_test_runner = builder.addRunArtifact(integration_tests);

            const integration_test_step = builder.step("test-integration", "Run integration tests");
            integration_test_step.dependOn(&integration_test_runner.step);

            const coverage_step = builder.step("coverage", "Generate coverage");

            const kcov = builder.findProgram(&.{
                "kcov",
            }, &.{}) catch |err| switch (err) {
                error.FileNotFound => "kcov",
                else => return err,
            };
            const include_pattern = builder.fmt("--include-pattern={s}/src/", .{
                builder.build_root.path.?,
            });
            const exclude_pattern = builder.fmt("--exclude-pattern={s}/,{s}/", .{
                builder.cache_root.path.?,
                builder.graph.global_cache_root.path.?,
            });
            const coverage_runner = builder.addSystemCommand(&.{
                kcov, "--clean", include_pattern, exclude_pattern, "coverage/",
            });

            coverage_runner.addArtifactArg(integration_tests);

            coverage_step.dependOn(&coverage_runner.step);

            break :step integration_test_step;
        };

        break :steps .{
            .unit_test_step = unit_test_step,
            .integration_test_step = integration_test_step,
        };
    };

    const test_step = builder.step("test", "Run all tests");
    test_step.dependOn(test_steps.unit_test_step);
    test_step.dependOn(test_steps.integration_test_step);
}
