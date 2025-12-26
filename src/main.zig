const std = @import("std");
const renderer = @import("renderer/device.zig");
const effects = @import("effects/mod.zig");

// Global allocator for the WASM module
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Global renderer instance
var ascii_renderer: ?renderer.AsciiRenderer = null;

// Export initialization function
export fn init(width: u32, height: u32, num_columns: u32, font_size: f32) bool {
    const config = renderer.Config{
        .width = width,
        .height = height,
        .num_columns = num_columns,
        .font_size = font_size,
        .colored = true,
        .blend = 0.0,
        .highlight = 0.0,
        .brightness = 1.0,
    };

    ascii_renderer = renderer.init(allocator, config) catch {
        std.debug.print("Failed to initialize renderer\n", .{});
        return false;
    };

    return true;
}

// Export function to update video frame from buffer
export fn updateVideoFrame(
    data: [*]const u8,
    width: u32,
    height: u32,
    stride: u32
) bool {
    if (ascii_renderer == null) return false;

    const slice = data[0 .. width * height * 4]; // Assuming RGBA format

    ascii_renderer.?.updateVideoFrame(slice, width, height, stride) catch {
        std.debug.print("Failed to update video frame\n", .{});
        return false;
    };

    return true;
}

// Export function to update mouse position (normalized 0-1)
export fn updateMouse(x: f32, y: f32) void {
    if (ascii_renderer) |*renderer| {
        renderer.updateMouse(x, y);
    }
}

// Export function to update audio level (0-1)
export fn updateAudio(level: f32, reactivity: f32, sensitivity: f32) void {
    if (ascii_renderer) |*renderer| {
        renderer.updateAudio(level, reactivity, sensitivity);
    }
}

// Export function to add ripple at position
export fn addRipple(x: f32, y: f32) void {
    if (ascii_renderer) |*renderer| {
        renderer.addRipple(x, y);
    }
}

// Export function to set rendering options
export fn setOptions(colored: bool, blend: f32, highlight: f32, brightness: f32) void {
    if (ascii_renderer) |*renderer| {
        renderer.setOptions(colored, blend, highlight, brightness);
    }
}

// Export function to render frame and get output buffer
export fn render() [*]const u8 {
    if (ascii_renderer) |*renderer| {
        const buffer = renderer.render() catch return null;
        return buffer.ptr;
    }
    return null;
}

// Export function to get output buffer size
export fn getOutputBufferSize() usize {
    if (ascii_renderer) |*renderer| {
        return renderer.getOutputBufferSize();
    }
    return 0;
}

// Export function to get grid dimensions
export fn getGridDimensions() struct { cols: u32, rows: u32 } {
    if (ascii_renderer) |*renderer| {
        return renderer.getGridDimensions();
    }
    return .{ .cols = 0, .rows = 0 };
}

// Export function to get performance stats
export fn getStats() struct { fps: f32, frame_time_ms: f32 } {
    if (ascii_renderer) |*renderer| {
        return renderer.getStats();
    }
    return .{ .fps = 0.0, .frame_time_ms = 0.0 };
}

// Export cleanup function
export fn cleanup() void {
    if (ascii_renderer) |*renderer| {
        renderer.deinit();
    }
    ascii_renderer = null;

    // Check for memory leaks
    const leaked = gpa.deinit();
    if (leaked == .leak) {
        std.debug.print("Memory leaks detected!\n", .{});
    }
}

// Panic handler for WASM
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    std.debug.print("PANIC: {s}\n", .{message});
    if (stack_trace) |trace| {
        std.debug.dumpStackTrace(trace.*);
    }
    @trap();
}
