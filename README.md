# zplay

`zplay` is a game development framework written from scratch in Zig. It aims to provide a simple and easy-to-use API for creating games.

## Features
Here are some features the project aims to provide. As the project is in very early development, lots of these features
might only work minimally or not work at all.
*   Managing windows(Multiple windows, multiple monitor)
*   Input event handling using keyboard, mouse and controllers
*   Rendering using vulkan with batching support and zig shaders
*   Audio playback
*   Math

## Getting Started

To use `zplay`, you need to have the latest master version of Zig and ZLS installed. The Zig ecosystem is moving fast, and `zplay` follows the master branch.

## Installation

To add `zplay` as a dependency to your project, you need to add it to your `build.zig.zon` file and then use it in your `build.zig`.

### 1. Add to `build.zig.zon`

Add the following to the `.dependencies` section of your `build.zig.zon` file:

```zon
.{
    .name = "your-game",
    .version = "0.0.0",
    .dependencies = .{
        .zplay = .{
            .url = "https://github.com/ricknijhuis/zplay/archive/main.tar.gz",
            // To get the latest hash, you can run `zig build` and the compiler
            // will tell you the expected hash.
            .hash = "<HASH_OF_THE_TARBALL>",
        },
    },
    // ...
}
```

### 2. Use in `build.zig`

In your `build.zig` file, add the `zplay` module to your executable:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "your-game",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add zplay as a dependency
    const zplay_dep = b.dependency("zplay", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("zplay", zplay_dep.module("zplay"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Example

Here is a simple example of how to create a window:

```zig
const std = @import("std");
const zp = @import("zplay");

const Window = zp.WindowHandle;
const Events = zp.Events;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    const window: Window = try .init(.{
        .mode = .{
            .windowed = .normal,
        },
        .title = "ZPlay Window",
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    const events: Events = try .init();

    while (!window.shouldClose()) {
        events.poll();
    }
}
```

You can find more examples in the [`examples`](https://github.com/ricknijhuis/zplay/tree/main/examples) directory.

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
