const c = @import("win32").everything;

const Win32Events = @This();

pub fn pollEvents(self: Win32Events) void {
    _ = self;

    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        switch (msg.message) {
            else => {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageW(&msg);
            },
        }
    }
}
