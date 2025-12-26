const std = @import("std");

// Configuration for the ASCII renderer
pub const Config = struct {
    width: u32,
    height: u32,
    num_columns: u32,
    font_size: f32 = 10.0,
    colored: bool = true,
    blend: f32 = 0.0,
    highlight: f32 = 0.0,
    brightness: f32 = 1.0,
    max_trail_length: u32 = 24,
    max_ripples: u32 = 8,
};

// ASCII character sets - ordered from dark to light
pub const Charset = enum {
    standard,
    blocks,
    minimal,
    binary,
    detailed,
    dots,
    arrows,
    emoji,

    pub fn getChars(self: Charset) []const u8 {
        return switch (self) {
            .standard => " .:-=+*#%@",
            .blocks => " ░▒▓█",
            .minimal => " .oO@",
            .binary => " █",
            .detailed => " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
            .dots => " ·•●",
            .arrows => " ←↙↓↘→↗↑↖",
            .emoji => "  ░▒▓🌑🌒🌓🌔🌕",
        };
    }

    pub fn getCharArray(self: Charset, allocator: std.mem.Allocator) ![]const u8 {
        const chars = self.getChars();
        const result = try allocator.alloc(u8, chars.len);
        std.mem.copy(u8, result, chars);
        return result;
    }
};

// Grid dimensions for ASCII output
pub const GridDimensions = struct {
    cols: u32,
    rows: u32,
    char_width: f32,
    char_height: f32,
};

// Performance statistics
pub const Stats = struct {
    fps: f32 = 0.0,
    frame_time_ms: f32 = 0.0,
    frame_count: u32 = 0,
    last_fps_update: u64 = 0,
};

// Mouse effect state
const MouseEffect = struct {
    x: f32 = -1.0, // Normalized 0-1, -1 means inactive
    y: f32 = -1.0,
    trail: struct {
        positions: [24]struct { x: f32, y: f32 },
        count: u32,
    } = .{
        .positions = [_]struct { x: f32, y: f32 }{.{ .x = -1, .y = -1 }} ** 24,
        .count = 0,
    },
};

// Ripple effect state
const Ripple = struct {
    x: f32,
    y: f32,
    start_time: f32,
    active: bool = true,
};

const RipplePool = struct {
    ripples: [8]Ripple = undefined,
    count: u32 = 0,
};

// Audio effect state
const AudioEffect = struct {
    level: f32 = 0.0,
    smoothed_level: f32 = 0.0,
    reactivity: f32 = 0.5,
    sensitivity: f32 = 0.5,
};

// Main renderer struct
pub const AsciiRenderer = struct {
    allocator: std.mem.Allocator,
    config: Config,

    // Grid and dimensions
    grid: GridDimensions,

    // Video texture data
    video_frame: ?[]u8 = null,
    video_width: u32 = 0,
    video_height: u32 = 0,
    video_stride: u32 = 0,

    // Output buffer
    output_buffer: []u8 = undefined,

    // Effects state
    mouse: MouseEffect = .{},
    ripples: RipplePool = .{},
    audio: AudioEffect = .{},

    // Performance tracking
    stats: Stats = .{},

    // Character set
    charset: []const u8 = undefined,

    // Time tracking
    start_time: u64 = 0,

    // Initialize the renderer
    pub fn init(allocator: std.mem.Allocator, config: Config) !AsciiRenderer {
        // Calculate grid dimensions
        const char_width = config.font_size * 0.6; // CHAR_WIDTH_RATIO
        const aspect_ratio = @intToFloat(f32, config.width) / @intToFloat(f32, config.height);
        const cols = config.num_columns;
        const rows = @as(u32, @floatToInt(u32, @round(@intToFloat(f32, cols) / aspect_ratio / 2.0)));

        const grid = GridDimensions{
            .cols = cols,
            .rows = rows,
            .char_width = char_width,
            .char_height = config.font_size,
        };

        // Allocate output buffer (RGBA for canvas)
        const output_width = @as(u32, @floatToInt(u32, @floor(@intToFloat(f32, cols) * char_width)));
        const output_height = @as(u32, @floatToInt(u32, @floor(@intToFloat(f32, rows) * config.font_size)));
        const output_buffer = try allocator.alloc(u8, output_width * output_height * 4);

        // Initialize character set
        const charset = try Charset.standard.getCharArray(allocator);

        // Initialize ripple pool
        var ripple_pool: RipplePool = .{};
        for (ripple_pool.ripples) |*r| {
            r.active = false;
        }

        return AsciiRenderer{
            .allocator = allocator,
            .config = config,
            .grid = grid,
            .output_buffer = output_buffer,
            .charset = charset,
            .start_time = std.time.milliTimestamp(),
        };
    }

    // Deinitialize and free resources
    pub fn deinit(self: *AsciiRenderer) void {
        if (self.video_frame) |frame| {
            self.allocator.free(frame);
        }
        self.allocator.free(self.output_buffer);
        self.allocator.free(self.charset);
    }

    // Update video frame from buffer
    pub fn updateVideoFrame(self: *AsciiRenderer, data: []const u8, width: u32, height: u32, stride: u32) !void {
        // Free old frame if exists
        if (self.video_frame) |old_frame| {
            self.allocator.free(old_frame);
        }

        // Copy new frame
        self.video_frame = try self.allocator.dupe(u8, data);
        self.video_width = width;
        self.video_height = height;
        self.video_stride = stride;
    }

    // Update mouse position
    pub fn updateMouse(self: *AsciiRenderer, x: f32, y: f32) void {
        // Add old position to trail if we had a valid position
        if (self.mouse.x >= 0.0 and self.mouse.y >= 0.0) {
            if (self.mouse.trail.count < self.config.max_trail_length) {
                self.mouse.trail.positions[self.mouse.trail.count] = .{ .x = self.mouse.x, .y = self.mouse.y };
                self.mouse.trail.count += 1;
            } else {
                // Shift trail
                std.mem.copy(struct { x: f32, y: f32 }, self.mouse.trail.positions[0..self.config.max_trail_length-1], self.mouse.trail.positions[1..self.config.max_trail_length]);
                self.mouse.trail.positions[self.config.max_trail_length - 1] = .{ .x = self.mouse.x, .y = self.mouse.y };
            }
        }

        self.mouse.x = x;
        self.mouse.y = y;
    }

    // Update audio level
    pub fn updateAudio(self: *AsciiRenderer, level: f32, reactivity: f32, sensitivity: f32) void {
        self.audio.reactivity = reactivity;
        self.audio.sensitivity = sensitivity;
        self.audio.level = level;

        // Smooth the level
        self.audio.smoothed_level = self.audio.smoothed_level * 0.7 + level * 0.3;
    }

    // Add ripple at position
    pub fn addRipple(self: *AsciiRenderer, x: f32, y: f32) void {
        const current_time = self.getCurrentTime();

        // Find inactive ripple slot
        for (self.ripples.ripples) |*ripple| {
            if (!ripple.active) {
                ripple.* = .{
                    .x = x,
                    .y = y,
                    .start_time = current_time,
                    .active = true,
                };
                self.ripples.count = @min(self.ripples.count + 1, self.config.max_ripples);
                return;
            }
        }

        // If all active, replace oldest (first one)
        if (self.ripples.ripples.len > 0) {
            self.ripples.ripples[0] = .{
                .x = x,
                .y = y,
                .start_time = current_time,
                .active = true,
            };
        }
    }

    // Set rendering options
    pub fn setOptions(self: *AsciiRenderer, colored: bool, blend: f32, highlight: f32, brightness: f32) void {
        self.config.colored = colored;
        self.config.blend = blend;
        self.config.highlight = highlight;
        self.config.brightness = brightness;
    }

    // Get current time in seconds
    fn getCurrentTime(self: *AsciiRenderer) f32 {
        const now = std.time.milliTimestamp();
        return @intToFloat(f32, now - self.start_time) / 1000.0;
    }

    // Calculate brightness from RGB values
    fn calculateBrightness(r: u8, g: u8, b: u8) f32 {
        const rf = @intToFloat(f32, r) / 255.0;
        const gf = @intToFloat(f32, g) / 255.0;
        const bf = @intToFloat(f32, b) / 255.0;
        return rf * 0.299 + gf * 0.587 + bf * 0.114;
    }

    // Get character index from brightness
    fn getCharIndex(self: *AsciiRenderer, brightness: f32) usize {
        // Apply brightness multiplier
        const audio_multiplier = std.math.lerp(
            std.math.lerp(0.3, 0.0, self.audio.sensitivity),
            std.math.lerp(1.0, 5.0, self.audio.sensitivity),
            self.audio.level
        );

        const audio_modulated = brightness * audio_multiplier;
        const final_brightness = std.math.lerp(brightness, audio_modulated, self.audio.reactivity);

        // Apply brightness adjustment
        const adjusted_brightness: f32 = if (self.config.brightness <= 1.0) {
            final_brightness * self.config.brightness;
        } else {
            1.0 - (1.0 - final_brightness) / self.config.brightness;
        };

        const clamped = std.math.clamp(adjusted_brightness, 0.0, 1.0);
        const num_chars_f = @intToFloat(f32, self.charset.len);
        return @floatToInt(usize, @floor(clamped * (num_chars_f - 0.001)));
    }

    // Get output buffer for rendering
    pub fn getOutputBuffer(self: *AsciiRenderer) []const u8 {
        return self.output_buffer;
    }

    // Get output buffer size
    pub fn getOutputBufferSize(self: *AsciiRenderer) usize {
        return self.output_buffer.len;
    }

    // Get grid dimensions
    pub fn getGridDimensions(self: *AsciiRenderer) struct { cols: u32, rows: u32 } {
        return .{ .cols = self.grid.cols, .rows = self.grid.rows };
    }

    // Get performance stats
    pub fn getStats(self: *AsciiRenderer) struct { fps: f32, frame_time_ms: f32 } {
        return .{ .fps = self.stats.fps, .frame_time_ms = self.stats.frame_time_ms };
    }

    // Render frame (placeholder - actual implementation would use WebGPU)
    // For now, this implements CPU-based rendering as fallback
    pub fn render(self: *AsciiRenderer) ![]const u8 {
        const start_time = std.time.nanoTimestamp();

        _ = self; // Suppress unused warning

        // TODO: Implement actual WebGPU rendering
        // For now, clear output buffer
        @memset(self.output_buffer, 0);

        // Track performance
        const end_time = std.time.nanoTimestamp();
        const frame_time_ms = @intToFloat(f32, end_time - start_time) / 1_000_000.0;

        self.stats.frame_count += 1;
        const now = std.time.milliTimestamp();
        if (now - self.stats.last_fps_update >= 1000) {
            self.stats.fps = @intToFloat(f32, self.stats.frame_count);
            self.stats.frame_time_ms = frame_time_ms;
            self.stats.frame_count = 0;
            self.stats.last_fps_update = now;
        }

        return self.output_buffer;
    }
};
