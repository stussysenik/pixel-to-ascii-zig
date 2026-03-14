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
            .blocks => " \xc2\x91\xc2\x92\xc2\x93\xe2\x96\x88",
            .minimal => " .oO@",
            .binary => " \xe2\x96\x88",
            .detailed => " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
            .dots => " \xc2\xb7\xe2\x80\xa2\xe2\x97\x8f",
            .arrows => " \xe2\x86\x90\xe2\x86\x99\xe2\x86\x93\xe2\x86\x98\xe2\x86\x92\xe2\x86\x97\xe2\x86\x91\xe2\x86\x96",
            .emoji => "  \xc2\x91\xc2\x92\xc2\x93\xf0\x9f\x8c\x91\xf0\x9f\x8c\x92\xf0\x9f\x8c\x93\xf0\x9f\x8c\x94\xf0\x9f\x8c\x95",
        };
    }

    pub fn getCharArray(self: Charset, allocator: std.mem.Allocator) ![]const u8 {
        const chars = self.getChars();
        const result = try allocator.alloc(u8, chars.len);
        @memcpy(result, chars);
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
    last_fps_update: i64 = 0,
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

    // Output buffer — per-cell format: [char_index, r, g, b] per grid cell
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
    start_time: i64 = 0,

    // Initialize the renderer
    pub fn init(allocator: std.mem.Allocator, config: Config) !AsciiRenderer {
        // Calculate grid dimensions
        const char_width = config.font_size * 0.6; // CHAR_WIDTH_RATIO
        const w_f: f32 = @floatFromInt(config.width);
        const h_f: f32 = @floatFromInt(config.height);
        const aspect_ratio = w_f / h_f;
        const cols = config.num_columns;
        const cols_f: f32 = @floatFromInt(cols);
        const rows: u32 = @intFromFloat(@round(cols_f / aspect_ratio / 2.0));

        const grid = GridDimensions{
            .cols = cols,
            .rows = rows,
            .char_width = char_width,
            .char_height = config.font_size,
        };

        // Allocate output buffer — per-cell: [char_index, r, g, b]
        const output_buffer = try allocator.alloc(u8, cols * rows * 4);

        // Initialize character set
        const charset = try Charset.standard.getCharArray(allocator);

        // Initialize ripple pool
        var ripple_pool: RipplePool = .{};
        for (&ripple_pool.ripples) |*r| {
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
                const len = self.config.max_trail_length;
                var i: u32 = 0;
                while (i < len - 1) : (i += 1) {
                    self.mouse.trail.positions[i] = self.mouse.trail.positions[i + 1];
                }
                self.mouse.trail.positions[len - 1] = .{ .x = self.mouse.x, .y = self.mouse.y };
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
        for (&self.ripples.ripples) |*ripple| {
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
        const delta: f32 = @floatFromInt(now - self.start_time);
        return delta / 1000.0;
    }

    // Calculate brightness from RGB values using perceptual luminance
    fn calculateBrightness(r: u8, g: u8, b: u8) f32 {
        const rf: f32 = @as(f32, @floatFromInt(r)) / 255.0;
        const gf: f32 = @as(f32, @floatFromInt(g)) / 255.0;
        const bf: f32 = @as(f32, @floatFromInt(b)) / 255.0;
        return rf * 0.299 + gf * 0.587 + bf * 0.114;
    }

    // Get character index from brightness with audio modulation
    fn getCharIndex(self: *AsciiRenderer, brightness: f32) usize {
        // Apply audio reactivity modulation
        const audio_multiplier = std.math.lerp(
            std.math.lerp(@as(f32, 0.3), @as(f32, 0.0), self.audio.sensitivity),
            std.math.lerp(@as(f32, 1.0), @as(f32, 5.0), self.audio.sensitivity),
            self.audio.level,
        );

        const audio_modulated = brightness * audio_multiplier;
        const final_brightness = std.math.lerp(brightness, audio_modulated, self.audio.reactivity);

        // Apply brightness adjustment
        const adjusted_brightness: f32 = if (self.config.brightness <= 1.0)
            final_brightness * self.config.brightness
        else
            1.0 - (1.0 - final_brightness) / self.config.brightness;

        const clamped = std.math.clamp(adjusted_brightness, 0.0, 1.0);
        const num_chars_f: f32 = @floatFromInt(self.charset.len);
        const idx: usize = @intFromFloat(@floor(clamped * (num_chars_f - 0.001)));
        return @min(idx, self.charset.len - 1);
    }

    // Calculate mouse glow effect intensity for a cell
    fn getMouseGlow(self: *AsciiRenderer, col_f: f32, row_f: f32) f32 {
        if (self.mouse.x < 0.0 or self.mouse.y < 0.0) return 0.0;

        const cols_f: f32 = @floatFromInt(self.grid.cols);
        const rows_f: f32 = @floatFromInt(self.grid.rows);

        // Convert mouse normalized coords to grid coords
        const mouse_col = self.mouse.x * cols_f;
        const mouse_row = self.mouse.y * rows_f;

        const dx = col_f - mouse_col;
        const dy = row_f - mouse_row;
        const dist = @sqrt(dx * dx + dy * dy);

        // 5-cell radius glow with smooth falloff
        const radius: f32 = 5.0;
        if (dist > radius) return 0.0;

        return (1.0 - dist / radius) * 0.4;
    }

    // Calculate ripple effect intensity for a cell
    fn getRippleEffect(self: *AsciiRenderer, col_f: f32, row_f: f32) f32 {
        const current_time = self.getCurrentTime();
        const cols_f: f32 = @floatFromInt(self.grid.cols);
        const rows_f: f32 = @floatFromInt(self.grid.rows);

        var total: f32 = 0.0;
        for (&self.ripples.ripples) |*ripple| {
            if (!ripple.active) continue;

            const age = current_time - ripple.start_time;
            if (age > 3.0) {
                ripple.active = false;
                continue;
            }

            // Convert ripple coords to grid space
            const rx = ripple.x * cols_f;
            const ry = ripple.y * rows_f;
            const dx = col_f - rx;
            const dy = row_f - ry;
            const dist = @sqrt(dx * dx + dy * dy);

            // Expanding ring: radius grows with time
            const ring_radius = age * 12.0;
            const ring_width: f32 = 2.0;
            const ring_dist = @abs(dist - ring_radius);

            if (ring_dist < ring_width) {
                // Fade with age and distance from ring center
                const fade = (1.0 - age / 3.0);
                const ring_intensity = (1.0 - ring_dist / ring_width);
                total += fade * ring_intensity * 0.3;
            }
        }

        return std.math.clamp(total, 0.0, 0.5);
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

    // Get grid columns count
    pub fn getGridCols(self: *AsciiRenderer) u32 {
        return self.grid.cols;
    }

    // Get grid rows count
    pub fn getGridRows(self: *AsciiRenderer) u32 {
        return self.grid.rows;
    }

    // Get performance stats
    pub fn getStats(self: *AsciiRenderer) struct { fps: f32, frame_time_ms: f32 } {
        return .{ .fps = self.stats.fps, .frame_time_ms = self.stats.frame_time_ms };
    }

    // Render frame — CPU-based ASCII conversion
    // For each grid cell: sample video pixel, compute brightness, apply effects,
    // write [char_index, r, g, b] to output buffer
    pub fn render(self: *AsciiRenderer) ![]const u8 {
        const start_ns = std.time.nanoTimestamp();

        const cols = self.grid.cols;
        const rows = self.grid.rows;

        // If no video frame, clear to spaces
        if (self.video_frame == null) {
            @memset(self.output_buffer, 0);
            return self.output_buffer;
        }

        const frame = self.video_frame.?;
        const vw = self.video_width;
        const vh = self.video_height;
        const stride = if (self.video_stride > 0) self.video_stride else vw * 4;

        const cols_f: f32 = @floatFromInt(cols);
        const rows_f: f32 = @floatFromInt(rows);
        const vw_f: f32 = @floatFromInt(vw);
        const vh_f: f32 = @floatFromInt(vh);

        var row: u32 = 0;
        while (row < rows) : (row += 1) {
            var col: u32 = 0;
            while (col < cols) : (col += 1) {
                const col_f: f32 = @floatFromInt(col);
                const row_f: f32 = @floatFromInt(row);

                // Map grid cell center to video pixel coordinate
                const sample_x: u32 = @intFromFloat(@floor((col_f + 0.5) / cols_f * vw_f));
                const sample_y: u32 = @intFromFloat(@floor((row_f + 0.5) / rows_f * vh_f));
                const sx = @min(sample_x, vw - 1);
                const sy = @min(sample_y, vh - 1);

                // Read RGBA from video frame
                const pixel_offset = sy * stride + sx * 4;
                if (pixel_offset + 3 >= frame.len) {
                    // Out of bounds — write blank cell
                    const out_idx = (row * cols + col) * 4;
                    self.output_buffer[out_idx] = 0;
                    self.output_buffer[out_idx + 1] = 0;
                    self.output_buffer[out_idx + 2] = 0;
                    self.output_buffer[out_idx + 3] = 0;
                    continue;
                }

                const r = frame[pixel_offset];
                const g = frame[pixel_offset + 1];
                const b = frame[pixel_offset + 2];

                // Calculate perceptual brightness
                var brightness = calculateBrightness(r, g, b);

                // Apply mouse glow effect
                const glow = self.getMouseGlow(col_f, row_f);
                brightness = std.math.clamp(brightness + glow, 0.0, 1.0);

                // Apply ripple effect
                const ripple = self.getRippleEffect(col_f, row_f);
                brightness = std.math.clamp(brightness + ripple, 0.0, 1.0);

                // Map brightness to character index (with audio modulation)
                const char_idx = self.getCharIndex(brightness);

                // Blend original color with brightness for colored mode
                var out_r = r;
                var out_g = g;
                var out_b = b;

                if (!self.config.colored) {
                    // Monochrome: map brightness to grayscale
                    const gray: u8 = @intFromFloat(std.math.clamp(brightness * 255.0, 0.0, 255.0));
                    out_r = gray;
                    out_g = gray;
                    out_b = gray;
                }

                // Apply highlight effect — boost bright areas
                if (self.config.highlight > 0.0) {
                    const highlight_boost = brightness * self.config.highlight;
                    const r_f: f32 = @floatFromInt(out_r);
                    const g_f: f32 = @floatFromInt(out_g);
                    const b_f: f32 = @floatFromInt(out_b);
                    out_r = @intFromFloat(std.math.clamp(r_f + highlight_boost * 64.0, 0.0, 255.0));
                    out_g = @intFromFloat(std.math.clamp(g_f + highlight_boost * 64.0, 0.0, 255.0));
                    out_b = @intFromFloat(std.math.clamp(b_f + highlight_boost * 64.0, 0.0, 255.0));
                }

                // Write per-cell output: [char_index, r, g, b]
                const out_idx = (row * cols + col) * 4;
                self.output_buffer[out_idx] = @intCast(char_idx);
                self.output_buffer[out_idx + 1] = out_r;
                self.output_buffer[out_idx + 2] = out_g;
                self.output_buffer[out_idx + 3] = out_b;
            }
        }

        // Track performance
        const end_ns = std.time.nanoTimestamp();
        const frame_time_ns = end_ns - start_ns;
        const frame_time_ms: f32 = @as(f32, @floatFromInt(frame_time_ns)) / 1_000_000.0;

        self.stats.frame_count += 1;
        const now = std.time.milliTimestamp();
        if (now - self.stats.last_fps_update >= 1000) {
            self.stats.fps = @floatFromInt(self.stats.frame_count);
            self.stats.frame_time_ms = frame_time_ms;
            self.stats.frame_count = 0;
            self.stats.last_fps_update = now;
        }

        return self.output_buffer;
    }
};
