const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;
const pl = @import("../root.zig");
const asserts = core.asserts;
const errors = core.errors;
const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;

const Monitor = @import("Monitor.zig");
const Window = @This();

const atom_name = utf8ToUtf16Lit("zplay");

pub const windowed_style = c.WS_OVERLAPPEDWINDOW;
pub const windowed_style_ex = c.WS_EX_APPWINDOW;

// 🖥️ True fullscreen (no borders, changes display mode)
pub const fullscreen_style = c.WS_POPUP;
pub const fullscreen_style_ex = c.WS_EX_APPWINDOW;

// 🪄 Borderless fullscreen window (covers monitor, no display mode change)
pub const fullscreen_borderless_style = c.WS_POPUP;
pub const fullscreen_borderless_style_ex = c.WS_EX_APPWINDOW;

handle: c.HWND,

pub fn create(gpa: std.mem.Allocator, title: []const u8) !Window {
    const h_instance: c.HINSTANCE = errors.panicIfNull(c.GetModuleHandleW(null), "Unable to get HINSTANCE");
    {
        // TODO: Should we panic here? Maybe return an error instead.
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

    const utf16_title = errors.panicIfError(utf8ToUtf16(gpa, title), "Failed to convert window title to UTF-16");
    defer gpa.free(utf16_title);

    // TODO: Should we panic here? Maybe return an error instead.
    const native_window = errors.panicIfNull(c.CreateWindowExW(
        windowed_style_ex,
        atom_name,
        utf16_title,
        windowed_style,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        1280,
        720,
        null,
        null,
        h_instance,
        null,
    ), "Failed to create native window");

    return .{
        .handle = native_window,
    };
}

pub fn destroy(self: *Window) void {
    _ = c.DestroyWindow(self.handle);
}

pub fn hide(self: *const Window) void {
    _ = c.ShowWindow(self.handle, c.SW_HIDE);
}

pub fn show(self: *const Window) void {
    _ = c.ShowWindow(self.handle, c.SW_SHOWNA);
}

pub fn maximize(self: *const Window) void {
    _ = c.ShowWindow(self.handle, c.SW_MAXIMIZE);
}

pub fn restore(self: *const Window) void {
    _ = c.ShowWindow(self.handle, c.SW_RESTORE);
}

pub fn minimize(self: *const Window) void {
    _ = c.ShowWindow(self.handle, c.SW_MINIMIZE);
}

pub fn resize(self: *const Window, width: u32, height: u32) void {
    _ = c.SetWindowPos(
        self.handle,
        null,
        0,
        0,
        @intCast(width),
        @intCast(height),
        .{ .NOZORDER = 1, .NOMOVE = 1 },
    );
}

pub fn decorate(self: *const Window) !void {
    c.SetWindowLong(self.handle, c.GWL_STYLE, windowed_style);
    c.SetWindowPos(
        self.handle,
        null,
        0,
        0,
        0,
        0,
        .{ .NOMOVE = 1, .NOSIZE = 1, .NOZORDER = 1, .DRAWFRAME = 1 },
    );
}

pub fn borderless(self: *const Window, monitor: *const Monitor) !void {
    const rect = try monitor.getFullArea();
    _ = c.SetWindowLongW(self.handle, c.GWL_STYLE, @bitCast(fullscreen_borderless_style));
    _ = c.SetWindowLongW(self.handle, c.GWL_EXSTYLE, @bitCast(fullscreen_borderless_style_ex));

    _ = c.SetWindowPos(
        self.handle,
        c.HWND_TOPMOST,
        rect.x(),
        rect.y(),
        rect.width(),
        rect.height(),
        .{ .DRAWFRAME = 1, .NOOWNERZORDER = 1 },
    );
}

pub fn fullscreen(self: *const Window, monitor: *const Monitor) !void {
    const rect = try monitor.getFullArea();

    _ = c.SetWindowLongW(self.handle, c.GWL_STYLE, @bitCast(fullscreen_style));
    _ = c.SetWindowLongW(self.handle, c.GWL_EXSTYLE, @bitCast(fullscreen_style_ex));

    std.log.info("pos: {any}", .{rect});
    _ = c.SetWindowPos(
        self.handle,
        c.HWND_TOPMOST,
        rect.x(),
        rect.y(),
        rect.width(),
        rect.height(),
        .{ .DRAWFRAME = 1 },
    );

    try monitor.setDisplaySize(rect.size.to(u32));
}

pub fn focus(self: *const Window) void {
    _ = c.BringWindowToTop(self.handle);
    _ = c.SetForegroundWindow(self.handle);
    _ = c.SetFocus(self.handle);
}

pub fn setUserPointer(self: *const Window, ptr: anytype) void {
    asserts.isPointer(ptr);
    _ = c.SetWindowLongPtrW(self.handle, c.GWLP_USERDATA, @intCast(@intFromPtr(ptr)));
}

pub fn getUserPointer(self: *const Window, T: type) *T {
    const ptr_value: usize = @intCast(c.GetWindowLongPtrW(self.handle, c.GWLP_USERDATA));
    return @ptrFromInt(ptr_value);
}

fn windowProcedure(hwnd: c.HWND, u_msg: u32, w_param: c.WPARAM, l_param: c.LPARAM) callconv(.c) isize {
    const wnd: Window = .{ .handle = hwnd };
    switch (u_msg) {
        c.WM_CLOSE => {
            pl.callbacks.onClose(wnd);
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        c.WM_DISPLAYCHANGE => {
            pl.callbacks.onDisplayChange();
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        c.WM_SIZE,
        c.WM_SETFOCUS,
        c.WM_KILLFOCUS,
        => {
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        else => {
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
    }
    return 0;
}
