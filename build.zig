const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
    // const example = b.option([]const u8, "example", "example to run (default: window") orelse "window";

    const test_step = b.step("test", "run tests");
    // const example_step = b.step("example", "build examples");
    const tmp_step = b.step("tmp", "build examples");

    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("src/runtime/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
        },
    });

    if (target.result.os.tag == .windows) {
        if (b.lazyDependency("win32", .{})) |win32_dep| {
            runtime_mod.addImport("win32", win32_dep.module("win32"));
        }
        runtime_mod.link_libc = true;
    }

    const zplay_mod = b.addModule("zplay", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core_mod },
            .{ .name = "runtime", .module = runtime_mod },
        },
    });

    const tmp_exe = b.addExecutable(.{
        .name = "tmp_exe",
        .version = version,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zplay", .module = zplay_mod },
            },
        }),
    });

    b.installArtifact(tmp_exe);

    const run_tmp_cmd = b.addRunArtifact(tmp_exe);
    run_tmp_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_tmp_cmd.addArgs(args);
    }

    tmp_step.dependOn(&run_tmp_cmd.step);

    // inline for (examples) |example_info| {
    //     if (std.mem.eql(u8, example_info.name, example)) {
    //         const example_exe = b.addExecutable(.{
    //             .name = example_info.name,
    //             .version = version,
    //             .root_module = b.createModule(.{
    //                 .root_source_file = b.path(example_info.path),
    //                 .target = target,
    //                 .optimize = optimize,
    //                 .imports = &.{
    //                     .{ .name = "zplay", .module = zplay_mod },
    //                 },
    //             }),
    //         });

    //         b.installArtifact(example_exe);

    //         const run_cmd = b.addRunArtifact(example_exe);
    //         run_cmd.step.dependOn(b.getInstallStep());

    //         if (b.args) |args| {
    //             run_cmd.addArgs(args);
    //         }

    //         example_step.dependOn(&run_cmd.step);
    //     }
    // }

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
    .{
        .name = "input",
        .path = "examples/basic/input.zig",
        .desc = "A basic input example",
    },
    .{
        .name = "multiple_windows",
        .path = "examples/basic/multiple_windows.zig",
        .desc = "A basic multiple windows example",
    },
    .{
        .name = "multiple_keyboards",
        .path = "examples/basic/multiple_keyboards.zig",
        .desc = "A basic multiple keyboard devices example",
    },
};
