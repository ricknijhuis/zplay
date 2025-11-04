const core = @import("core");
const gpa = @import("gpa.zig");

const StringTable = core.StringTable;

pub const Internal = struct {
    pub var instance: core.StringTable = undefined;

    pub fn init() !void {
        instance = .empty;
    }

    pub fn deinit() void {
        instance.deinit(gpa.Internal.instance);
    }
};
