const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;
const app = @import("../app.zig");
const wnd = @import("../window.zig");
const kb = @import("../keyboard.zig");
const errors = core.errors;

const Platform = @import("Platform.zig");
const Allocator = std.mem.Allocator;
const HandleSet = core.HandleSet;
const Handle = HandleSet(wnd.Internal).Handle;

const Win32Window = @This();

const instance = &app.Internal.instance;
const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;
const prop_name = "zplay_platform";
const main_class_name = utf8ToUtf16Lit("zplay");
const child_class_name = utf8ToUtf16Lit("zplay_child");
const windowed_style = c.WS_OVERLAPPEDWINDOW;
const windowed_style_ex = c.WS_EX_APPWINDOW;

handle: c.HWND,

pub fn create(self: *wnd.Internal, handle: Handle, gpa: Allocator) !void {
    // No main window register yet, create it.
    // The first created window is always the main window and will use the main window procedure. This procedure will handle
    // messages that are not window specific, such as display changes and device changes.
    // See mainWindowProcedure and childWindowProcedure for the specifics.
    var window_class_name: [*:0]const u16 = child_class_name;
    if (instance.platform.impl.main_window_class == null or instance.platform.impl.child_window_class == null) {
        var class: c.WNDCLASSEXW = .{
            .cbSize = @sizeOf(c.WNDCLASSEXW),
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .style = .{
                .HREDRAW = 1,
                .VREDRAW = 1,
                .OWNDC = 1,
            },
            .hInstance = instance.platform.impl.instance,
            // TODO: Allow for custom Icon
            .hIcon = c.LoadIconW(null, c.IDI_APPLICATION),
            // TODO: Allow for custom Cursor
            .hCursor = c.LoadCursorW(null, c.IDC_ARROW),
            .lpszMenuName = null,
            .hbrBackground = null,
            .hIconSm = null,
            .lpszClassName = undefined, // Set later
            .lpfnWndProc = undefined, // Set later
        };

        if (instance.platform.impl.main_window_class == null) {
            class.lpfnWndProc = mainWindowProcedure;
            class.lpszClassName = main_class_name;
            instance.platform.impl.main_window_class = c.RegisterClassExW(&class);
            // TODO: Should we panic here? Maybe return an error instead.
            errors.panicIfZero(instance.platform.impl.main_window_class.?, "Failed to register main window class");
        } else {
            class.lpfnWndProc = childWindowProcedure;
            class.lpszClassName = child_class_name;
            instance.platform.impl.child_window_class = c.RegisterClassExW(&class);
            // TODO: Should we panic here? Maybe return an error instead.
            errors.panicIfZero(instance.platform.impl.child_window_class.?, "Failed to register child window class");
        }
    }

    if (instance.windows.count == 1) {
        window_class_name = main_class_name[0..];
    } else {
        window_class_name = child_class_name[0..];
    }

    const title = instance.strings.getSlice(self.title);
    const utf16_title = errors.panicIfError(utf8ToUtf16(gpa, title), "Failed to convert window title to UTF-16");
    defer gpa.free(utf16_title);

    // TODO: Should we panic here? Maybe return an error instead.
    const native_window = errors.panicIfNull(c.CreateWindowExW(
        windowed_style_ex,
        window_class_name,
        utf16_title,
        windowed_style,
        c.CW_USEDEFAULT,
        c.CW_USEDEFAULT,
        @intCast(self.full.width()),
        @intCast(self.full.height()),
        null,
        null,
        instance.platform.impl.instance,
        null,
    ), "Failed to create native window");

    self.impl.handle = native_window;

    // Store the handle, NOT POINTER to self as the pointer might be invalidated if the window buffer resizes.
    try setWindowLongPtr(self.impl.handle, handle.toInt());
}

pub fn destroy(self: *const wnd.Internal) void {
    _ = c.DestroyWindow(self.impl.handle);
}

pub fn hide(self: *const wnd.Internal) void {
    _ = c.ShowWindow(self.impl.handle, c.SW_HIDE);
}

pub fn show(self: *const wnd.Internal) void {
    _ = c.ShowWindow(self.impl.handle, c.SW_SHOWNA);
}

pub fn maximize(self: *const wnd.Internal) void {
    _ = c.ShowWindow(self.impl.handle, c.SW_MAXIMIZE);
}

pub fn restore(self: *const wnd.Internal) void {
    _ = c.ShowWindow(self.impl.handle, c.SW_RESTORE);
}

pub fn minimize(self: *const wnd.Internal) void {
    _ = c.ShowWindow(self.impl.handle, c.SW_MINIMIZE);
}

pub fn fullRect(self: *const wnd.Internal) core.Rect(i32) {
    var wnd_rect: c.RECT = undefined;
    _ = c.GetWindowRect(self.impl.handle, &wnd_rect);

    return .{
        .position = .init(wnd_rect.left, wnd_rect.top),
        .size = .init(@intCast(wnd_rect.right - wnd_rect.left), @intCast(wnd_rect.bottom - wnd_rect.top)),
    };
}

pub fn contentRect(self: *const wnd.Internal) core.Rect(i32) {
    var client_rect: c.RECT = undefined;
    _ = c.GetClientRect(self.impl.handle, &client_rect);

    var top_left: c.POINT = .{ .x = client_rect.left, .y = client_rect.top };
    _ = c.ClientToScreen(self.impl.handle, &top_left);

    return .{
        .position = .init(top_left.x, top_left.y),
        .size = .init(@intCast(client_rect.right - client_rect.left), @intCast(client_rect.bottom - client_rect.top)),
    };
}

pub fn resize(self: *const wnd.Internal, width: u32, height: u32) void {
    _ = c.SetWindowPos(
        self.impl.handle,
        null,
        0,
        0,
        @intCast(width),
        @intCast(height),
        .{ .NOZORDER = 1, .NOMOVE = 1 },
    );
}

pub fn decorate(self: *const wnd.Internal) !void {
    c.SetWindowLong(self.impl.handle, c.GWL_STYLE, windowed_style);
    c.SetWindowPos(
        self.impl.handle,
        null,
        0,
        0,
        0,
        0,
        .{
            .NOMOVE = 1,
            .NOSIZE = 1,
            .NOZORDER = 1,
            .DRAWFRAME = 1,
        },
    );
}

// Main window procedure this will handle all types of messages
fn mainWindowProcedure(hwnd: c.HWND, u_msg: u32, w_param: c.WPARAM, l_param: c.LPARAM) callconv(.c) isize {
    return switch (u_msg) {
        c.WM_DISPLAYCHANGE => {
            instance.platform.event_flags.monitors_changed = true;
            return 0;
        },
        c.WM_DEVICECHANGE => {
            instance.platform.event_flags.input_devices_changed = true;
            return 0;
        },
        else => childWindowProcedure(hwnd, u_msg, w_param, l_param),
    };
}

// Child window procedure this will handle window specific messages
fn childWindowProcedure(hwnd: c.HWND, u_msg: u32, w_param: c.WPARAM, l_param: c.LPARAM) callconv(.c) isize {
    const handle = getWindowLongPtr(u32, hwnd);
    return switch (u_msg) {
        c.WM_SETFOCUS => {
            instance.focused = .fromInt(handle);
            syncKeys();
            return 0;
        },
        c.WM_KILLFOCUS => {
            kb.Internal.reset();
            return 0;
        },
        c.WM_CLOSE => {
            instance.windows.getPtr(.fromInt(handle)).should_close = true;
            return 0;
        },
        c.WM_SIZE => {
            var window = instance.windows.getPtr(.fromInt(handle));
            window.content.size = .init(
                @intCast(c.loword(l_param)),
                @intCast(c.hiword(l_param)),
            );
            return 0;
        },
        c.WM_MOVE => {
            var window = instance.windows.getPtr(.fromInt(handle));
            window.content.position = .init(
                @intCast(c.xFromLparam(l_param)),
                @intCast(c.yFromLparam(l_param)),
            );
            return 0;
        },
        c.WM_WINDOWPOSCHANGED => {
            const pos: *c.WINDOWPOS = @ptrFromInt(@as(usize, @intCast(l_param)));
            var window = instance.windows.getPtr(.fromInt(handle));
            window.full = .init(pos.x, pos.y, pos.cx, pos.cy);
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
        else => {
            return c.DefWindowProcW(hwnd, u_msg, w_param, l_param);
        },
    };
}

fn getWindowLongPtr(comptime T: type, hwnd: c.HWND) T {
    const raw: usize = @intCast(c.GetWindowLongPtrW(hwnd, c.GWLP_USERDATA));
    return switch (@typeInfo(T)) {
        .pointer => @ptrFromInt(raw),
        .int, .comptime_int => @intCast(raw),
        else => @compileError("getWindowLongPtr: expected pointer or integer type"),
    };
}

fn setWindowLongPtr(hwnd: c.HWND, value: anytype) !void {
    const val: usize = switch (@typeInfo(@TypeOf(value))) {
        .pointer => @intFromPtr(value),
        .int, .comptime_int => @intCast(value),
        else => @compileError("setWindowLongPtr: expected pointer or integer type"),
    };

    c.SetLastError(.NO_ERROR);
    _ = c.SetWindowLongPtrW(hwnd, c.GWLP_USERDATA, @intCast(val));
    const err = c.GetLastError();
    try errors.throwIfNotTrue(err == .NO_ERROR, error.SetWindowLongPtrFailed, "Failed to set window long ptr");
}

fn syncKeys() void {
    const user32 = std.os.windows.user32;

    inline for (@typeInfo(Platform.Scancode).Enum.fields) |field| {
        const encoded: Platform.Scancode = @enumFromInt(field.value);

        const full_scancode = Platform.Scancode.decode(encoded);

        const vk = user32.MapVirtualKeyExA(full_scancode, std.os.windows.MAPVK_VSC_TO_VK_EX, null);
        if (vk == 0) continue;

        const state: i16 = user32.GetAsyncKeyState(vk);
        const is_down = (state & (1 << 15)) != 0;

        const key = instance.platform.impl.keycodes_map[@intFromEnum(encoded)];

        kb.Internal.process(key, is_down);
    }
}
