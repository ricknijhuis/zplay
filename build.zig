const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
    const example = b.option([]const u8, "example", "example to run (default: window") orelse "window";

    const test_step = b.step("test", "run tests");
    const example_step = b.step("example", "build examples");

    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const modules_mod = b.createModule(.{
        .root_source_file = b.path("src/modules/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
        },
    });

    if (target.result.os.tag == .windows) {
        if (b.lazyDependency("win32", .{})) |win32_dep| {
            modules_mod.addImport("win32", win32_dep.module("win32"));
        }
    }

    const zplay_mod = b.addModule("zplay", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
            .{ .name = "modules", .module = modules_mod },
        },
    });

    inline for (examples) |example_info| {
        if (std.mem.eql(u8, example_info.name, example)) {
            const example_exe = b.addExecutable(.{
                .name = example_info.name,
                .version = version,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(example_info.path),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{
                        .{ .name = "zplay", .module = zplay_mod },
                    },
                }),
            });

            example_step.dependOn(&example_exe.step);
        }
    }

    const core_tests = b.addTest(.{
        .root_module = core_mod,
    });

    const run_core_tests = b.addRunArtifact(core_tests);
    test_step.dependOn(&run_core_tests.step);
}

const Example = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
};
const examples = [_]Example{
    .{
        .name = "window",
        .path = "examples/basic/window.zig",
        .desc = "A basic window example",
    },
};
