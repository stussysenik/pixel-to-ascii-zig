const std = @import("std");
const renderer = @import("renderer/device.zig");
const effects = @import("effects/mod.zig");

// Global allocator for the WASM module
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Global renderer instance
var ascii_renderer: ?renderer.AsciiRenderer = null;

// Export initialization function
export fn init(width: u32, height: u32, num_columns: u32, font_size: f32) callconv(.C) bool {
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

    ascii_renderer = renderer.AsciiRenderer.init(allocator, config) catch {
        return false;
    };

    return true;
}

// Export function to update video frame from buffer
export fn updateVideoFrame(
    data: [*]const u8,
    width: u32,
    height: u32,
    stride: u32,
) callconv(.C) bool {
    if (ascii_renderer == null) return false;

    const slice = data[0 .. width * height * 4]; // RGBA format

    ascii_renderer.?.updateVideoFrame(slice, width, height, stride) catch {
        return false;
    };

    return true;
}

// Export function to update mouse position (normalized 0-1)
export fn updateMouse(x: f32, y: f32) callconv(.C) void {
    if (ascii_renderer) |*r| {
        r.updateMouse(x, y);
    }
}

// Export function to update audio level (0-1)
export fn updateAudio(level: f32, reactivity: f32, sensitivity: f32) callconv(.C) void {
    if (ascii_renderer) |*r| {
        r.updateAudio(level, reactivity, sensitivity);
    }
}

// Export function to add ripple at position
export fn addRipple(x: f32, y: f32) callconv(.C) void {
    if (ascii_renderer) |*r| {
        r.addRipple(x, y);
    }
}

// Export function to set rendering options
export fn setOptions(colored: bool, blend: f32, highlight: f32, brightness: f32) callconv(.C) void {
    if (ascii_renderer) |*r| {
        r.setOptions(colored, blend, highlight, brightness);
    }
}

// Export function to render frame and get output buffer
export fn render() callconv(.C) [*]const u8 {
    if (ascii_renderer) |*r| {
        const buffer = r.render() catch return @as([*]const u8, @ptrFromInt(0));
        return buffer.ptr;
    }
    return @as([*]const u8, @ptrFromInt(0));
}

// Export function to get output buffer size
export fn getOutputBufferSize() callconv(.C) usize {
    if (ascii_renderer) |*r| {
        return r.getOutputBufferSize();
    }
    return 0;
}

// Export function to get grid columns
export fn getGridCols() callconv(.C) u32 {
    if (ascii_renderer) |*r| {
        return r.getGridCols();
    }
    return 0;
}

// Export function to get grid rows
export fn getGridRows() callconv(.C) u32 {
    if (ascii_renderer) |*r| {
        return r.getGridRows();
    }
    return 0;
}

// Export function to get performance stats
export fn getStats() callconv(.C) u64 {
    if (ascii_renderer) |*r| {
        const stats = r.getStats();
        // Pack fps and frame_time into u64 (two f32s)
        const fps_bits: u32 = @bitCast(stats.fps);
        const ft_bits: u32 = @bitCast(stats.frame_time_ms);
        return @as(u64, fps_bits) | (@as(u64, ft_bits) << 32);
    }
    return 0;
}

// Export cleanup function
export fn cleanup() callconv(.C) void {
    if (ascii_renderer) |*r| {
        r.deinit();
    }
    ascii_renderer = null;

    // Check for memory leaks
    const check = gpa.deinit();
    if (check == .leak) {
        @panic("Memory leaks detected!");
    }
}

// C ABI prefixed wrappers for Swift/native consumers
export fn pta_init(width: u32, height: u32, num_columns: u32, font_size: f32) callconv(.C) bool {
    return init(width, height, num_columns, font_size);
}

export fn pta_update_video_frame(data: [*]const u8, width: u32, height: u32, stride: u32) callconv(.C) bool {
    return updateVideoFrame(data, width, height, stride);
}

export fn pta_render() callconv(.C) [*]const u8 {
    return render();
}

export fn pta_get_grid_cols() callconv(.C) u32 {
    return getGridCols();
}

export fn pta_get_grid_rows() callconv(.C) u32 {
    return getGridRows();
}

export fn pta_set_options(colored: bool, blend: f32, highlight: f32, brightness: f32) callconv(.C) void {
    return setOptions(colored, blend, highlight, brightness);
}

export fn pta_update_mouse(x: f32, y: f32) callconv(.C) void {
    return updateMouse(x, y);
}

export fn pta_add_ripple(x: f32, y: f32) callconv(.C) void {
    return addRipple(x, y);
}

export fn pta_cleanup() callconv(.C) void {
    return cleanup();
}

// Panic handler for WASM — Zig 0.13+ signature
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: usize) noreturn {
    _ = msg;
    @trap();
}
