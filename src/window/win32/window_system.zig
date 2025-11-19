const core = @import("core");
const c = @import("win32").everything;
const errors = core.errors;

pub const WindowSystem = struct {
    instance: c.HINSTANCE,
    main_window_class: ?u16,
    child_window_class: ?u16,

    pub fn init() !WindowSystem {
        return .{
            .instance = errors.panicIfNull(c.GetModuleHandleW(null), "Unable to get HINSTANCE"),
            .main_window_class = null,
            .child_window_class = null,
        };
    }
};
