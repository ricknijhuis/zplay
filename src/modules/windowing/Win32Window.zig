const std = @import("std");
const c = @import("win32").everything;
const mods = @import("../root.zig");

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;

const Win32Window = @This();

const atom_name = utf8ToUtf16Lit("zplay");

handle: c.HWND,

pub fn init() !Win32Window {
    const gpa = modules.gpa;

    const instance: c.HINSTANCE = blk: {
        if (c.GetModuleHandleW(null)) |handle| {
            break :blk handle;
        } else {
            return error.Win32NoModuleHandleFound;
        }
    };

    const window_class: c.WNDCLASSEXW = .{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
        .lpfnWndProc = windowProcedure,
        .hInstance = instance,
        .hIcon = c.LoadIconW(null, c.IDI_APPLICATION),
        .hCursor = c.LoadCursorW(null, c.IDC_ARROW),
        .lpszClassName = atom_name,
        .lpszMenuName = null,
        .hbrBackground = null,
        .hIconSm = null,
    };

    try checkResult(c.RegisterClassExW(&window_class) != 0);

    const title = try utf8ToUtf16(gpa, "zplay");
    defer gpa.free(title);

    const style = 
}

fn getWindowStyle(mode: Window.Mode) c.WINDOW_STYLE {
    switch (mode) {
        .windowed => {
            return .{ .CLIPSIBLINGS = 1, .CLIPCHILDREN = 1,.SYSMENU = 1, .THICKFRAME = 1 .OVERLAPPED = 1 };
        },
        .borderless, .fullscreen => {
            return .{ .POPUP = 1 };
        },
    }
    return .{};
}

fn getWindowStyleEx(mode: Window.Mode) c.WINDOW_EX_STYLE {
    if (mode == Window.Mode.fullscreen or mode == Window.Mode.borderless) {
        return .{ .APPWINDOW = 1, .TOPMOST = 1};
    } else {
        return .{.APPWINDOW};
    }
    return .{};
}

fn checkResult(ok: bool) std.os.UnexpectedError!void {
    if (ok) return;

    const err = c.GetLastError();
    if (std.os.unexpected_error_tracing) {
        // 614 is the length of the longest windows error description
        var buf_wstr: [614:0]u16 = undefined;
        var buf_utf8: [614:0]u8 = undefined;
        const len = c.FormatMessageW(
            c.FORMAT_MESSAGE_FROM_SYSTEM | c.FORMAT_MESSAGE_IGNORE_INSERTS,
            null,
            err,
            c.MAKELANGID(c.LANG_NEUTRAL, c.SUBLANG_DEFAULT),
            &buf_wstr,
            buf_wstr.len,
            null,
        );
        _ = std.unicode.utf16leToUtf8(&buf_utf8, buf_wstr[0..len]) catch unreachable;
        std.debug.print("error.Unexpected: GetLastError({}): {s}\n", .{ err, buf_utf8[0..len] });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}
