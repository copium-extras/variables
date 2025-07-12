const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
});

// --- Global variables to hold our state ---
// We need to store the window pointer so other functions can access it.
var g_window: ?*c.SDL_Window = null;

// --- 1. Initialization Function ---
// This will be called once at the beginning.
// Returns 0 on success, non-zero on failure.
pub export fn init() c_int {
    // In SDL3, SDL_Init returns true on success and false on failure.
    // The check should be for `== false` to catch errors.
    if (c.SDL_Init(c.SDL_INIT_VIDEO) == false) {
        std.log.err("SDL_Init Error: {s}", .{c.SDL_GetError()});
        return 1; // Error code 1: SDL init failed
    }

    g_window = c.SDL_CreateWindow(
        "Hello from Zig DLL",
        640,
        480,
        c.SDL_WINDOW_RESIZABLE,
    );

    if (g_window == null) {
        std.log.err("SDL_CreateWindow Error: {s}", .{c.SDL_GetError()});
        c.SDL_Quit(); // Clean up SDL if window creation fails
        return 2; // Error code 2: Window creation failed
    }

    std.log.info("Zig DLL initialized successfully.", .{});
    return 0; // Success
}

// --- 2. Event Polling Function ---
// This will be called repeatedly in a loop by Python.
// Returns `true` if the app should quit, `false` otherwise.
pub export fn poll_events() bool {
    var event: c.SDL_Event = undefined;

    // Process all events currently in the queue
    while (c.SDL_PollEvent(&event) != false) {
        if (event.type == c.SDL_EVENT_QUIT) {
            return true; // Signal to quit
        }
    }
    return false; // Signal to continue
}

// --- 3. Shutdown Function ---
// This will be called once at the end.
pub export fn shutdown() void {
    if (g_window) |win| {
        c.SDL_DestroyWindow(win);
        g_window = null;
    }
    c.SDL_Quit();
    std.log.info("Zig DLL shut down gracefully.", .{});
}
