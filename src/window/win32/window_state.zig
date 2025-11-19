const std = @import("std");
const core = @import("core");
const c = @import("win32").everything;

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeAllocZ;
const prop_name = "zplay_platform";
const main_class_name = utf8ToUtf16Lit("zplay");
const child_class_name = utf8ToUtf16Lit("zplay_child");
const windowed_style = c.WS_OVERLAPPEDWINDOW;
const windowed_style_ex = c.WS_EX_APPWINDOW;

pub const WindowStateWin32 = struct {
    handle: c.HWND,

    pub fn init() !WindowStateWin32 {}

    pub fn fullRect(self: WindowStateWin32) core.Rect(i32) {
        var wnd_rect: c.RECT = undefined;
        _ = c.GetWindowRect(self.impl.handle, &wnd_rect);

        return .init(wnd_rect.left, wnd_rect.top, wnd_rect.right - wnd_rect.left, wnd_rect.bottom - wnd_rect.top);
        // return .{
        //     .position = .init(wnd_rect.left, wnd_rect.top),
        //     .size = .init(@intCast(wnd_rect.right - wnd_rect.left), @intCast(wnd_rect.bottom - wnd_rect.top)),
        // };
    }

    pub fn contentRect(self: WindowStateWin32) core.Rect(i32) {
        var client_rect: c.RECT = undefined;
        _ = c.GetClientRect(self.impl.handle, &client_rect);

        var top_left: c.POINT = .{ .x = client_rect.left, .y = client_rect.top };
        _ = c.ClientToScreen(self.impl.handle, &top_left);

        return .init(wnd_rect.left, wnd_rect.top, wnd_rect.right - wnd_rect.left, wnd_rect.bottom - wnd_rect.top);
        // return .{
        //     .position = .init(top_left.x, top_left.y),
        //     .size = .init(@intCast(client_rect.right - client_rect.left), @intCast(client_rect.bottom - client_rect.top)),
        // };
    }
};
