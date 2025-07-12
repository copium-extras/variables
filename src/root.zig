const std = @import("std");

pub export fn init() c_int {
    std.log.info("Zig DLL initialized successfully.", .{});
    return 0; // Success
}

// --- 2. Event Polling Function ---
// This will be called repeatedly in a loop by Python.
// Returns `true` if the app should quit, `false` otherwise.
pub export fn poll_events() bool {
    return true; // Signal to continue
}

// --- 3. Shutdown Function ---
// This will be called once at the end.
pub export fn shutdown() void {
    std.log.info("Zig DLL shut down gracefully.", .{});
}
