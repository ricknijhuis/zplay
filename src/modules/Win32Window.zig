const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;
const errors = core.errors;
const debug = std.debug;

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;

const WindowHandle = @import("WindowHandle.zig");
const MonitorHandle = @import("MonitorHandle.zig");
const InitParams = WindowHandle.InitParams;
const Mode = WindowHandle.Mode;

const Win32Window = @This();

const instance = &@import("context.zig").instance;
const atom_name = utf8ToUtf16Lit("zplay");

window: c.HWND,

pub fn init(handle: WindowHandle, params: InitParams) MonitorHandle.QueryMonitorError!Win32Window {
    const gpa = instance.gpa;

    const h_instance: c.HINSTANCE = errors.panicIfNull(c.GetModuleHandleW(null), "Unable to get HINSTANCE");
    {
        const window_class: c.WNDCLASSEXW = .{
            .cbSize = @sizeOf(c.WNDCLASSEXW),
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .style = .{
                .HREDRAW = 1,
                .VREDRAW = 1,
                .OWNDC = 1,
            },
            .lpfnWndProc = windowProcedure,
            .hInstance = h_instance,
            .hIcon = c.LoadIconW(null, c.IDI_APPLICATION),
            .hCursor = c.LoadCursorW(null, c.IDC_ARROW),
            .lpszClassName = atom_name,
            .lpszMenuName = null,
            .hbrBackground = null,
            .hIconSm = null,
        };

        errors.panicIfZero(c.RegisterClassExW(&window_class), "Failed to register window class");
    }

    const title = errors.panicIfError(utf8ToUtf16(gpa, params.title), "Failed to convert window title to UTF-16");
    defer gpa.free(title);

    const style = getWindowStyle(params.mode);
    const style_ex = getWindowStyleEx(params.mode);

    var pos_x: i32 = c.CW_USEDEFAULT;
    var pos_y: i32 = c.CW_USEDEFAULT;
    var width: i32 = @intCast(params.width);
    var height: i32 = @intCast(params.height);

    switch (params.mode) {
        .fullscreen, .borderless => |monitor_handle| {
            const rect = try monitor_handle.getFullArea();
            pos_x = rect.x();
            pos_y = rect.y();
            width = rect.width();
            height = rect.height();
        },
        .windowed => {},
    }

    // TODO: Handle multi monitor setups.
    // TODO: Handle DPI scaling.
    const native_window = errors.panicIfNull(c.CreateWindowExW(
        style_ex,
        atom_name,
        title,
        style,
        pos_x,
        pos_y,
        width,
        height,
        null,
        null,
        h_instance,
        null,
    ), "Failed to create native window");

    const window: Win32Window = .{
        .window = native_window,
    };

    // Annoyingly, SetWindowLongPtrW can return 0 on both success and failure, so we have to check GetLastError to see if it actually failed.
    c.SetLastError(.NO_ERROR);
    const result = c.SetWindowLongPtrW(native_window, .P_USERDATA, @intCast(handle.handle.toInt()));
    const err = c.GetLastError();
    errors.panicIfNotTrue(!(result == 0 and err != .NO_ERROR), "Failed to set window long ptr");

    switch (params.mode) {
        .fullscreen, .borderless => {
            _ = c.SetWindowPos(
                native_window,
                c.HWND_TOPMOST,
                pos_x,
                pos_y,
                width,
                height,
                .{
                    .NOOWNERZORDER = 1,
                    .DRAWFRAME = 1, // Same as FRAMECHANGED
                },
            );
            window.show();
            window.focus();
        },
        .windowed => |mode| {
            switch (mode) {
                .normal => {
                    window.show();
                    window.focus();
                },
                .minimized => {
                    window.minimize();
                },
                .maximized => {
                    window.maximize();
                    window.focus();
                },
                .hidden => {
                    window.hide();
                },
            }
        },
    }

    return window;
}

pub fn deinit(self: *Win32Window) void {
    _ = c.DestroyWindow(self.window);
}

pub fn hide(self: *const Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_HIDE);
}

pub fn show(self: *const Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_SHOWNA);
}

pub fn maximize(self: *const Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_MAXIMIZE);
}

pub fn restore(self: *const Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_RESTORE);
}

pub fn minimize(self: *const Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_MINIMIZE);
}

pub fn fullscreen(self: *const Win32Window, monitor: MonitorHandle) MonitorHandle.QueryMonitorError!void {
    const rect = try monitor.getFullArea();

    _ = c.SetWindowPos(
        self.window,
        c.HWND_TOPMOST,
        rect.x(),
        rect.y(),
        rect.width(),
        rect.height(),
        c.SWP_FRAMECHANGED | c.SWP_NOOWNERZORDER,
    );
}

pub fn focus(self: *const Win32Window) void {
    _ = c.BringWindowToTop(self.window);
    _ = c.SetForegroundWindow(self.window);
    _ = c.SetFocus(self.window);
}

fn getWindowStyle(mode: Mode) c.WINDOW_STYLE {
    switch (mode) {
        .windowed => {
            return c.WS_OVERLAPPEDWINDOW;
        },
        .borderless, .fullscreen => {
            return .{ .POPUP = 1 };
        },
    }
    return .{};
}

fn getWindowStyleEx(mode: Mode) c.WINDOW_EX_STYLE {
    var style_ex: c.WINDOW_EX_STYLE = .{
        .APPWINDOW = 1,
        // .NOREDIRECTIONBITMAP = 1,
    };
    if (mode == .fullscreen or mode == .borderless) {
        style_ex.TOPMOST = 1;
    }
    return style_ex;
}

fn windowProcedure(hwnd: c.HWND, u_msg: u32, w_param: c.WPARAM, l_param: c.LPARAM) callconv(.c) isize {
    const handle: WindowHandle = .{
        .handle = .fromInt(@intCast(c.GetWindowLongPtrW(hwnd, .P_USERDATA))),
    };
    const window = instance.windows.getPtr(handle.handle);

    switch (u_msg) {
        c.WM_DISPLAYCHANGE => {
            // Win32WMonitor.poll() catch {};
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        c.WM_SIZE => {
            const width: u32 = @intCast(l_param & 0xFFFF);
            const height: u32 = @intCast((l_param >> 16) & 0xFFFF);

            window.width = width;
            window.height = height;

            return 0;
        },
        c.WM_SETFOCUS => {
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        c.WM_KILLFOCUS => {},
        c.WM_CLOSE => {
            window.should_close = true;

            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        c.WM_INPUT => {
            // var input: c.RAWINPUT = .{};
            // var input_size: c_uint = @sizeOf(@TypeOf(input));
            // _ = c.GetRawInputData(lParam, c.RID_INPUT, &input, &input_size, @as(c_uint, @sizeOf(c.RAWINPUTHEADER)));

            // if (input.header.dwType == c.RIM_TYPEKEYBOARD) {
            //     var pressed = false;
            //     const ignore = 0;
            //     _ = ignore;
            //     var scancode = input.data.keyboard.MakeCode;
            //     const flags: c_int = input.data.keyboard.Flags;

            //     if ((flags & c.RI_KEY_BREAK) == 0)
            //         pressed = true;

            //     if (flags & c.RI_KEY_E0 != 0) {
            //         scancode |= 0xE000;
            //     } else if (flags & c.RI_KEY_E1 != 0)
            //         scancode |= 0xE100;

            //     if (scancode == 0xE11D or scancode == 0xE02A or scancode == 0xE0AA or scancode == 0xE0B6 or scancode == 0xE036)
            //         return 0;

            //     std.log.debug("scancode: {}, pressed: {}", .{ scancode, pressed });

            // internal_set_keyboard_key(engine, ae_platform_get_key_code_index(scancode), pressed);
            // break;
            // }

            return 0;
        },
        else => {
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
    }
    return 0;
}
