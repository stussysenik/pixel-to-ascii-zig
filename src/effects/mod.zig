// Effects module - organizes all visual effects
// Provides unified interface for mouse, ripple, and audio effects

const std = @import("std");

// Maximum limits for effects
pub const MAX_TRAIL_LENGTH = 24;
pub const MAX_RIPPLES = 8;

// Effect configuration
pub const EffectsConfig = struct {
    // Mouse effect
    mouse_enabled: bool = true,
    trail_length: u32 = 24,

    // Ripple effect
    ripple_enabled: bool = false,
    ripple_speed: f32 = 40.0,

    // Audio effect
    audio_enabled: bool = false,
    audio_reactivity: f32 = 0.5,
    audio_sensitivity: f32 = 0.5,
};

// Mouse effect state
pub const MouseEffect = struct {
    const Point = struct { x: f32, y: f32 };

    x: f32 = -1.0, // Normalized 0-1, -1 means inactive
    y: f32 = -1.0,
    trail: struct {
        positions: [MAX_TRAIL_LENGTH]Point,
        count: u32,
    } = .{
        .positions = [_]Point{.{ .x = -1, .y = -1 }} ** MAX_TRAIL_LENGTH,
        .count = 0,
    },

    // Update mouse position
    pub fn update(self: *MouseEffect, x: f32, y: f32, trail_length: u32) void {
        // Add old position to trail if we had a valid position
        if (self.x >= 0.0 and self.y >= 0.0) {
            if (self.trail.count < trail_length) {
                self.trail.positions[self.trail.count] = .{ .x = self.x, .y = self.y };
                self.trail.count += 1;
            } else {
                // Shift trail to make room
                const max_idx = @as(usize, trail_length) - 1;
                var i: usize = 0;
                while (i < max_idx) : (i += 1) {
                    self.trail.positions[i] = self.trail.positions[i + 1];
                }
                self.trail.positions[max_idx] = .{ .x = self.x, .y = self.y };
            }
        }

        self.x = x;
        self.y = y;
    }

    // Reset mouse state (when mouse leaves)
    pub fn reset(self: *MouseEffect) void {
        self.x = -1.0;
        self.y = -1.0;
        self.trail.count = 0;
    }

    // Get uniform data for shader
    pub fn getUniformData(self: *const MouseEffect) struct {
        mouse: [2]f32,
        radius: f32,
        trail_length: u32,
        trail: [MAX_TRAIL_LENGTH * 2]f32,
    } {
        var trail_array: [MAX_TRAIL_LENGTH * 2]f32 = undefined;

        // Pack trail positions into flat array
        for (self.trail.positions, 0..) |pos, i| {
            trail_array[i * 2] = pos.x;
            trail_array[i * 2 + 1] = pos.y;
        }

        return .{
            .mouse = [_]f32{ self.x, self.y },
            .radius = 5.0,
            .trail_length = self.trail.count,
            .trail = trail_array,
        };
    }
};

// Ripple effect state
pub const Ripple = struct {
    x: f32,
    y: f32,
    start_time: f32,
    active: bool = true,
};

pub const RippleEffect = struct {
    ripples: [MAX_RIPPLES]Ripple,
    count: u32 = 0,

    // Initialize all ripples as inactive
    pub fn init() RippleEffect {
        var effect: RippleEffect = undefined;
        for (&effect.ripples) |*r| {
            r.active = false;
        }
        return effect;
    }

    // Add a new ripple at position
    pub fn add(self: *RippleEffect, x: f32, y: f32, current_time: f32) void {
        // Find inactive ripple slot
        for (&self.ripples) |*ripple| {
            if (!ripple.active) {
                ripple.* = .{
                    .x = x,
                    .y = y,
                    .start_time = current_time,
                    .active = true,
                };
                self.count = @min(self.count + 1, MAX_RIPPLES);
                return;
            }
        }

        // If all active, replace oldest (first one)
        self.ripples[0] = .{
            .x = x,
            .y = y,
            .start_time = current_time,
            .active = true,
        };
    }

    // Update ripple state, remove old ripples
    pub fn update(self: *RippleEffect, current_time: f32, max_lifetime: f32) void {
        var active_count: u32 = 0;

        for (&self.ripples) |*ripple| {
            if (ripple.active) {
                const age = current_time - ripple.start_time;
                if (age > max_lifetime) {
                    ripple.active = false;
                } else {
                    active_count += 1;
                }
            }
        }

        self.count = active_count;
    }

    // Get uniform data for shader
    pub fn getUniformData(self: *const RippleEffect) struct {
        enabled: f32,
        speed: f32,
        ripples: [MAX_RIPPLES * 4]f32,
    } {
        var ripple_array: [MAX_RIPPLES * 4]f32 = undefined;

        // Pack ripple data into flat array (x, y, start_time, enabled)
        for (self.ripples, 0..) |ripple, i| {
            ripple_array[i * 4] = ripple.x;
            ripple_array[i * 4 + 1] = ripple.y;
            ripple_array[i * 4 + 2] = ripple.start_time;
            ripple_array[i * 4 + 3] = if (ripple.active) 1.0 else 0.0;
        }

        return .{
            .enabled = if (self.count > 0) 1.0 else 0.0,
            .speed = 40.0,
            .ripples = ripple_array,
        };
    }
};

// Audio effect state
pub const AudioEffect = struct {
    level: f32 = 0.0,
    smoothed_level: f32 = 0.0,
    reactivity: f32 = 0.5,
    sensitivity: f32 = 0.5,

    // Update audio level with smoothing
    pub fn update(self: *AudioEffect, level: f32) void {
        self.level = level;
        // Exponential smoothing for smooth transitions
        self.smoothed_level = self.smoothed_level * 0.7 + level * 0.3;
    }

    // Set reactivity parameters
    pub fn setReactivity(self: *AudioEffect, reactivity: f32, sensitivity: f32) void {
        self.reactivity = reactivity;
        self.sensitivity = sensitivity;
    }

    // Get uniform data for shader
    pub fn getUniformData(self: *const AudioEffect) struct { level: f32, reactivity: f32, sensitivity: f32 } {
        return .{
            .level = self.smoothed_level,
            .reactivity = self.reactivity,
            .sensitivity = self.sensitivity,
        };
    }
};

// Unified effects manager
pub const EffectsManager = struct {
    config: EffectsConfig,
    mouse: MouseEffect = .{},
    ripples: RippleEffect = .{},
    audio: AudioEffect = .{},

    // Initialize effects manager with configuration
    pub fn init(config: EffectsConfig) EffectsManager {
        return EffectsManager{
            .config = config,
            .ripples = RippleEffect.init(),
        };
    }

    // Update mouse position
    pub fn updateMouse(self: *EffectsManager, x: f32, y: f32) void {
        if (self.config.mouse_enabled) {
            self.mouse.update(x, y, self.config.trail_length);
        }
    }

    // Reset mouse (when mouse leaves)
    pub fn resetMouse(self: *EffectsManager) void {
        self.mouse.reset();
    }

    // Add ripple at position
    pub fn addRipple(self: *EffectsManager, x: f32, y: f32, current_time: f32) void {
        if (self.config.ripple_enabled) {
            self.ripples.add(x, y, current_time);
        }
    }

    // Update audio level
    pub fn updateAudio(self: *EffectsManager, level: f32) void {
        if (self.config.audio_enabled) {
            self.audio.update(level);
        }
    }

    // Update all effects (call each frame)
    pub fn updateAll(self: *EffectsManager, current_time: f32, grid_cols: u32, grid_rows: u32) void {
        if (self.config.ripple_enabled) {
            // Calculate maximum ripple lifetime based on grid size
            const gc: f32 = @floatFromInt(grid_cols);
            const gr: f32 = @floatFromInt(grid_rows);
            const max_dist = @sqrt(gc * gc + gr * gr);
            const max_lifetime = max_dist / self.config.ripple_speed + 1.0;
            self.ripples.update(current_time, max_lifetime);
        }
    }

    // Check if any effects are active
    pub fn hasActiveEffects(self: *const EffectsManager) bool {
        return self.config.mouse_enabled or self.config.ripple_enabled or self.config.audio_enabled;
    }

    // Update configuration
    pub fn updateConfig(self: *EffectsManager, new_config: EffectsConfig) void {
        self.config = new_config;
        self.audio.setReactivity(new_config.audio_reactivity, new_config.audio_sensitivity);
    }
};
