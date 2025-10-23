const std = @import("std");
const c = @import("win32").everything;
const debug = std.debug;

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;

const WindowHandle = @import("WindowHandle.zig");
const Win32WMonitor = @import("Win32Monitor.zig");
const InitParams = WindowHandle.InitParams;
const Mode = WindowHandle.Mode;

const Win32Window = @This();

const instance = &@import("context.zig").instance;
const atom_name = utf8ToUtf16Lit("zplay");

window: c.HWND,

pub fn init(handle: WindowHandle, params: InitParams) !Win32Window {
    const gpa = instance.gpa;

    const h_instance: c.HINSTANCE = blk: {
        if (c.GetModuleHandleW(null)) |value| {
            break :blk value;
        } else {
            return error.Win32NoModuleHandleFound;
        }
    };

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

        try checkResult(c.RegisterClassExW(&window_class) != 0);
    }

    const title = try utf8ToUtf16(gpa, params.title);
    defer gpa.free(title);

    const style = getWindowStyle(params.mode);
    const style_ex = getWindowStyleEx(params.mode);

    // TODO: Handle multi monitor setups.
    // TODO: Handle DPI scaling.

    var window_rect = try getPrimaryMonitorRect();
    const monitor_width = window_rect.right - window_rect.left;
    const monitor_height = window_rect.bottom - window_rect.top;
    const window_width: c_long = @intCast(params.width);
    const window_height: c_long = @intCast(params.height);
    const denominator: c_long = 2;

    if (params.mode == .windowed) {
        window_rect.left = @divExact(monitor_width, denominator) - @divExact(window_width, denominator);
        window_rect.top = @divExact(monitor_height, denominator) - @divExact(window_height, denominator);
        window_rect.right = window_rect.left + window_width;
        window_rect.bottom = window_rect.top + window_height;

        try checkResult(c.AdjustWindowRectEx(&window_rect, style, c.FALSE, style_ex) == c.TRUE);
    }

    const window = c.CreateWindowExW(
        style_ex,
        atom_name,
        title,
        style,
        window_rect.left,
        window_rect.top,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
        null,
        null,
        h_instance,
        null,
    );

    try checkResult(window != null);
    try checkResult(c.SetWindowLongPtrW(window, .P_USERDATA, @intCast(handle.handle.toInt())) == 0);

    switch (params.mode) {
        .fullscreen => {
            _ = c.ShowWindow(window, c.SW_SHOWMAXIMIZED);
        },
        .borderless, .windowed => |mode| {
            switch (mode) {
                .normal => {
                    _ = c.ShowWindow(window, c.SW_SHOWNORMAL);
                },
                .minimized => {
                    _ = c.ShowWindow(window, c.SW_SHOWMINIMIZED);
                },
                .maximized => {
                    _ = c.ShowWindow(window, c.SW_SHOWMAXIMIZED);
                },
                .hidden => {
                    _ = c.ShowWindow(window, c.SW_HIDE);
                },
            }
        },
    }

    return .{
        .window = window.?,
    };
}

pub fn deinit(self: *Win32Window) void {
    _ = c.DestroyWindow(self.window);
}

pub fn maximize(self: *Win32Window) void {
    _ = self;
}

pub fn minimize(self: *Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_SHOWMINIMIZED);
}

pub fn fullscreen(self: *Win32Window) void {
    _ = c.ShowWindow(self.window, c.SW_SHOWMAXIMIZED);
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
        .NOREDIRECTIONBITMAP = 1,
    };
    if (mode == .fullscreen or mode == .borderless) {
        style_ex.TOPMOST = 1;
    }
    return style_ex;
}

fn getPrimaryMonitorRect() !c.RECT {
    const pt_zero = c.POINT{ .x = 0, .y = 0 };
    const monitor = c.MonitorFromPoint(pt_zero, c.MONITOR_DEFAULTTONEAREST);
    var monitor_info = c.MONITORINFO{
        .cbSize = @sizeOf(c.MONITORINFO),
        .dwFlags = undefined,
        .rcMonitor = undefined,
        .rcWork = undefined,
    };

    try checkResult(c.GetMonitorInfoW(monitor, &monitor_info) != 0);

    return monitor_info.rcMonitor;
}

// TODO: Improve error handling, log errors.
fn checkResult(ok: bool) !void {
    if (ok) return;
    return error.Unexpected;
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
