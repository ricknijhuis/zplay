const ctx = @import("context.zig");

const App = @import("App.zig");
const Event = @import("Event.zig");
const Monitor = @import("Monitor.zig");
const Keyboard = @import("Keyboard.zig");
const Window = @import("Window.zig");

// Define namespaces here to specify what is exposed
// This allows components to contain private functions and types not exposed globally
// Only expose functions here that operate on the global context, for operations on
// specific instances, those should be defined within their respective modules

/// Application-related functions for initializing and deinitializing the global context.
pub const app = struct {
    pub const init = App.init;
    pub const deinit = App.deinit;
};

/// Event-related functions that operate on the global context.
pub const event = struct {
    pub const poll = Event.poll;
    pub const getEventDevice = Event.getEventDevice;
};

/// Monitor-related functions that operate on the global context.
pub const monitor = struct {
    pub const poll = Monitor.poll;
    pub const primary = Monitor.primary;
    pub const closest = Monitor.closest;
};

/// Keyboard-related functions that operate on the global context.
pub const keyboard = struct {
    pub const init = Keyboard.init;
};

/// Window-related functions that operate on the global context.
pub const window = struct {
    pub const create = Window.create;
    pub const destroy = Window.destroy;
};

// Expose handles that operate on individual instances
pub const WindowHandle = @import("WindowHandle.zig");
pub const MonitorHandle = @import("MonitorHandle.zig");
pub const KeyboardHandle = @import("KeyboardHandle.zig");

pub const InputDeviceId = ctx.InputDeviceId;
pub const KeyboardId = ctx.KeyboardId;
