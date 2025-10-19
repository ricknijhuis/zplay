const zp = @import("zplay");

// const Modules = zp.Modules;
// const ModulesConfig = zp.ModulesConfig;
// const Window = pz.WindowHandle;
// const Keyboard = pz.KeyboardHandle;
// const Mouse = pz.MouseHandle;

pub fn main() !void {
    try zp.init(null);
    defer zp.deinit();

    // const modules: ModulesConfig = .{
    //     .windowing = true,
    // };

    // try Modules(modules).init();

    // const window: Window = try .init();
    // const keyboard: Keyboard = try .init(window);
    // const mouse: MouseHandle = try .init(window);

    // while (!window.shouldClose()) {}
}
