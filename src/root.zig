const std = @import("std");

const log = std.log.scoped(.var_system);

// --- GLOBAL STATE ---
// The allocator MUST be global so its memory remains valid for the lifetime of the DLL.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// A global pointer to our variable system.
var g_var_system: *VariableSystem = undefined;

// --- TYPE DEFINITIONS (Unchanged) ---
const ValueType = enum { number, boolean, string, array, object, null };
const JsObject = std.StringHashMap(Value);
const JsArray = std.ArrayList(Value);

const Value = union(ValueType) {
    number: f64,
    boolean: bool,
    string: []const u8,
    array: JsArray,
    object: JsObject,
    null: void,

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |*arr| {
                for (arr.items) |*item| item.deinit(allocator);
                arr.deinit();
            },
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            .number, .boolean, .null => {},
        }
    }
    pub fn format(
        self: Value,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // We can ignore fmt_str and options for this simple case.
        _ = fmt_str;
        _ = options;

        // Switch on the type of the union and print the raw value.
        switch (self) {
            .number => |n| try writer.print("{}", .{n}),
            .boolean => |b| try writer.print("{}", .{b}),
            .string => |s| try writer.writeAll(s),
            .null => try writer.writeAll("null"),
            // For this example, we'll just describe composite types.
            .array => try writer.writeAll("[array]"),
            .object => try writer.writeAll("{object}"),
        }
    }
};

const Variable = struct {
    is_const: bool,
    value: Value,
};

const VariableSystem = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(Variable),

    pub fn init(allocator: std.mem.Allocator) VariableSystem {
        return .{
            .allocator = allocator,
            .variables = std.StringHashMap(Variable).init(allocator),
        };
    }

    pub fn deinit(self: *VariableSystem) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.value.deinit(self.allocator);
        }
        self.variables.deinit();
    }
};

// --- EXPORTED DLL FUNCTIONS (Corrected) ---

pub export fn init() c_int {
    // Get an allocator interface from our GLOBAL allocator.
    const allocator = gpa.allocator();

    // Create the VariableSystem struct using our now-stable allocator.
    g_var_system = allocator.create(VariableSystem) catch {
        log.err("Failed to allocate memory for VariableSystem", .{});
        return -1;
    };
    g_var_system.* = VariableSystem.init(allocator);

    log.info("Zig DLL and VariableSystem initialized successfully.", .{});
    return 0; // Success
}

pub export fn shutdown() void {
    // First, deinitialize our system, which frees all variable memory.
    g_var_system.deinit();

    // Now free the VariableSystem struct itself.
    gpa.allocator().destroy(g_var_system);

    // Finally, deinitialize the global allocator.
    const leaked = gpa.deinit();

    if (leaked == .leak) {
        log.err("MEMORY LEAK DETECTED! Some memory was allocated but not freed.", .{});
    }

    log.info("Zig DLL and VariableSystem shut down gracefully.", .{});
}

pub export fn poll_events() bool {
    return true; // Unused in this example
}

fn is_const(access: [*c]const u8) bool {
    return std.mem.eql(u8, std.mem.span(access), "const");
}

pub export fn make(name: [*c]const u8, access: [*c]const u8, type_str: [*c]const u8, value_str: [*c]const u8) c_int {
    // This function will now work correctly because the allocator is valid.
    const var_system = g_var_system;
    const allocator = var_system.allocator;

    const name_slice = std.mem.span(name);
    const type_slice = std.mem.span(type_str);
    const value_slice = std.mem.span(value_str);

    var value: Value = .null;
    if (std.mem.eql(u8, type_slice, "number")) {
        value = .{ .number = std.fmt.parseFloat(f64, value_slice) catch 0.0 };
    } else if (std.mem.eql(u8, type_slice, "boolean")) {
        value = .{ .boolean = std.mem.eql(u8, value_slice, "true") };
    } else if (std.mem.eql(u8, type_slice, "string")) {
        const new_str = allocator.dupe(u8, value_slice) catch return -1;
        value = .{ .string = new_str };
    } else {
        log.warn("Unsupported type for make: {s}", .{type_slice});
        return -1;
    }

    const new_var = Variable{
        .is_const = is_const(access),
        .value = value,
    };

    const name_copy = allocator.dupe(u8, name_slice) catch {
        value.deinit(allocator);
        return -1;
    };

    var_system.variables.put(name_copy, new_var) catch {
        allocator.free(name_copy);
        value.deinit(allocator);
        return -1;
    };

    return 0;
}

pub export fn mod(name: [*c]const u8, type_str: [*c]const u8, value_str: [*c]const u8) c_int {
    const var_system = g_var_system;
    const allocator = var_system.allocator;
    const name_slice = std.mem.span(name);

    var entry = var_system.variables.getEntry(name_slice) orelse {
        log.warn("Variable not found for mod: {s}", .{name_slice});
        return -1;
    };

    if (entry.value_ptr.is_const) {
        log.warn("Cannot modify const variable: {s}", .{name_slice});
        return -2;
    }

    entry.value_ptr.value.deinit(allocator);

    const type_slice = std.mem.span(type_str);
    const value_slice = std.mem.span(value_str);
    var new_value: Value = .null;

    if (std.mem.eql(u8, type_slice, "number")) {
        new_value = .{ .number = std.fmt.parseFloat(f64, value_slice) catch 0.0 };
    } else if (std.mem.eql(u8, type_slice, "boolean")) {
        new_value = .{ .boolean = std.mem.eql(u8, value_slice, "true") };
    } else if (std.mem.eql(u8, type_slice, "string")) {
        new_value = .{ .string = allocator.dupe(u8, value_slice) catch return -3 };
    } else {
        log.warn("Unsupported type for mod: {s}", .{type_slice});
        return -4;
    }

    entry.value_ptr.value = new_value;
    return 0;
}

pub export fn remove(name: [*c]const u8) c_int {
    const var_system = g_var_system;
    const name_slice = std.mem.span(name);

    var removed_entry = var_system.variables.fetchRemove(name_slice) orelse {
        log.warn("Variable not found for remove: {s}", .{name_slice});
        return -1;
    };

    removed_entry.value.value.deinit(var_system.allocator);
    var_system.allocator.free(removed_entry.key);
    return 0;
}

/// Gets the type of a variable, returned as an integer.
/// Corresponds to the ValueType enum (0=number, 1=boolean, 2=string, etc).
/// Returns -1 if the variable is not found.
pub export fn get_type(name: [*c]const u8) c_int {
    const var_system = g_var_system;
    const name_slice = std.mem.span(name);

    const variable = var_system.variables.get(name_slice) orelse {
        return -1; // Not found
    };

    return @intFromEnum(variable.value);
}

/// Gets the value of a variable by formatting it into a string buffer
/// provided by the caller.
///
/// Returns the number of bytes written to the buffer on success.
/// Returns -1 if the variable is not found.
/// Returns -2 if the provided buffer is too small.
pub export fn get_value_as_string(name: [*c]const u8, buffer: [*c]u8, buffer_len: usize) c_int {
    const var_system = g_var_system;
    const name_slice = std.mem.span(name);

    const variable = var_system.variables.get(name_slice) orelse {
        return -1; // Not found
    };

    const many_item_ptr: [*]u8 = @ptrCast(buffer);

    const buffer_slice = many_item_ptr[0..buffer_len];

    const bytes_written = std.fmt.bufPrint(buffer_slice, "{}", .{variable.value}) catch |err| {
        log.warn("Buffer too small to get value for '{s}'. Error: {}", .{ name_slice, err });
        return -2;
    };

    return @intCast(bytes_written.len);
}
