// Fragment shader for ASCII effect rendering
// Converts video to ASCII art with interactive effects

// Uniform bindings
struct FragmentUniforms {
    // Resolution and dimensions
    u_resolution: vec2<f32>,    // Output resolution in pixels
    u_charSize: vec2<f32>,      // Character size in pixels (width, height)
    u_gridSize: vec2<f32>,      // Grid dimensions (cols, rows)

    // Character mapping
    u_numChars: f32,            // Number of characters in charset

    // Rendering options
    u_colored: f32,             // 1.0 = colored, 0.0 = green terminal
    u_blend: f32,               // Blend with original video (0-1)
    u_highlight: f32,           // Background highlight intensity (0-1)
    u_brightness: f32,          // Brightness multiplier

    // Audio reactivity
    u_audioLevel: f32,          // Current audio level (0-1)
    u_audioReactivity: f32,     // Audio reactivity strength (0-1)
    u_audioSensitivity: f32,     // Audio sensitivity (0-1)

    // Time for ripple animation
    u_time: f32,
};

@group(0) @binding(0) var<uniform> uniforms: FragmentUniforms;
@group(0) @binding(1) var u_video: texture_2d<f32>;
@group(0) @binding(2) var u_video_sampler: sampler;
@group(0) @binding(3) var u_asciiAtlas: texture_2d<f32>;
@group(0) @binding(4) var u_atlas_sampler: sampler;

// Mouse effect uniforms
struct MouseUniforms {
    u_mouse: vec2<f32>,         // Current mouse position (normalized 0-1)
    u_mouseRadius: f32,         // Mouse glow radius in grid cells
    u_trailLength: i32,         // Number of trail positions
};

@group(1) @binding(0) var<uniform> mouse: MouseUniforms;
@group(1) @binding(1) var<storage> u_trail: array<vec2<f32>>; // Trail positions

// Ripple effect uniforms
struct Ripple {
    x: f32,
    y: f32,
    start_time: f32,
    enabled: f32,
};

@group(2) @binding(0) var<storage> u_ripples: array<Ripple>;
@group(2) @binding(1) var<uniform> u_rippleConfig: vec2<f32>; // (enabled, speed)

// Fragment input from vertex shader
struct FragmentInput {
    @location(0) texCoord: vec2<f32>,
};

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Calculate which ASCII cell this pixel belongs to
    let cellCoord = floor(input.texCoord * uniforms.u_gridSize);
    let thisCell = cellCoord;

    // Sample video at cell center (mipmaps handle averaging)
    let cellCenter = (cellCoord + vec2<f32>(0.5, 0.5)) / uniforms.u_gridSize;
    let videoColor = textureSample(u_video, u_video_sampler, cellCenter);

    // Calculate perceived brightness using human eye sensitivity weights
    let baseBrightness = dot(videoColor.rgb, vec3<f32>(0.299, 0.587, 0.114));

    // Audio reactivity - louder = brighter, silence = darker
    let minBrightness = mix(0.3, 0.0, uniforms.u_audioSensitivity);
    let maxBrightness = mix(1.0, 5.0, uniforms.u_audioSensitivity);
    let audioMultiplier = mix(minBrightness, maxBrightness, uniforms.u_audioLevel);
    let audioModulated = baseBrightness * audioMultiplier;
    let brightness = mix(baseBrightness, audioModulated, uniforms.u_audioReactivity);

    // Cursor glow - blocky circle effect
    var cursorGlow = 0.0;
    let cursorRadius = 5.0;

    let mouseCell = floor(mouse.u_mouse * uniforms.u_gridSize);
    let cellDist = length(thisCell - mouseCell);
    if (cellDist <= cursorRadius && mouse.u_mouse.x >= 0.0) {
        cursorGlow += 1.0 - cellDist / cursorRadius;
    }

    // Trail effect
    let trailLength = min(mouse.u_trailLength, 24);
    for (var i: i32 = 0; i < 24; i++) {
        if (i >= trailLength) {
            break;
        }
        let trailPos = u_trail[i];
        if (trailPos.x < 0.0) {
            continue;
        }

        let trailCell = floor(trailPos * uniforms.u_gridSize);
        let trailDist = length(thisCell - trailCell);
        let trailRadius = cursorRadius * 0.8;

        if (trailDist <= trailRadius) {
            let fade = 1.0 - f32(i) / f32(trailLength);
            cursorGlow += (1.0 - trailDist / trailRadius) * 0.5 * fade;
        }
    }
    cursorGlow = min(cursorGlow, 1.0);

    // Ripple effect - expanding rings on click
    var rippleGlow = 0.0;
    let rippleEnabled = u_rippleConfig.x > 0.5;
    if (rippleEnabled) {
        for (var i: i32 = 0; i < 8; i++) {
            let ripple = u_ripples[i];
            if (ripple.enabled < 0.5) {
                continue;
            }

            let age = uniforms.u_time - ripple.start_time;
            if (age < 0.0) {
                continue;
            }

            let rippleCell = floor(vec2<f32>(ripple.x, ripple.y) * uniforms.u_gridSize);
            let cellDist = length(thisCell - rippleCell);
            let initialRadius = 5.0;

            let distFromEdge = max(0.0, cellDist - initialRadius);
            let rippleSpeed = u_rippleConfig.y;
            let reachTime = distFromEdge / rippleSpeed;
            let timeSinceReached = age - reachTime;

            let fadeDuration = 0.5;
            if (timeSinceReached >= 0.0 && timeSinceReached < fadeDuration) {
                let pop = 1.0 - timeSinceReached / fadeDuration;
                let popSquared = pop * pop;
                rippleGlow += popSquared * 0.3;
            }
        }
        rippleGlow = min(rippleGlow, 1.0);
    }

    // Apply brightness multiplier
    // brightness < 1.0: darkens (multiply)
    // brightness > 1.0: brightens (compress dark values toward 1.0)
    var adjustedBrightness: f32;
    if (uniforms.u_brightness <= 1.0) {
        adjustedBrightness = brightness * uniforms.u_brightness;
    } else {
        // For brightness > 1.0, compress the range: dark values get pushed up
        // Formula: 1.0 - (1.0 - brightness) / u_brightness
        // This makes dark values brighter while keeping bright values near 1.0
        adjustedBrightness = 1.0 - (1.0 - brightness) / uniforms.u_brightness;
    }
    adjustedBrightness = clamp(adjustedBrightness, 0.0, 1.0);

    // Map brightness to character index (0 = darkest char, numChars-1 = brightest)
    let charIndex = floor(adjustedBrightness * (uniforms.u_numChars - 0.001));

    // Find the character in the atlas (horizontal strip of pre-rendered chars)
    let atlasX = charIndex / uniforms.u_numChars;
    let cellPos = fract(input.texCoord * uniforms.u_gridSize);
    let atlasCoord = vec2<f32>(
        atlasX + cellPos.x / uniforms.u_numChars,
        cellPos.y
    );
    let charColor = textureSample(u_asciiAtlas, u_atlas_sampler, atlasCoord);

    // Pick the color - video colors or green terminal aesthetic
    var baseColor: vec3<f32>;
    if (uniforms.u_colored > 0.5) {
        baseColor = videoColor.rgb;
    } else {
        baseColor = vec3<f32>(0.0, 1.0, 0.0);
    }

    // Background highlight behind each character
    let bgIntensity = 0.15 + uniforms.u_highlight * 0.35;
    let bgColor = baseColor * bgIntensity;
    let textColor = baseColor * 1.2;
    let finalColor = mix(bgColor, textColor, charColor.r);

    // Add cursor and ripple glow
    finalColor += cursorGlow * baseColor * 0.5;
    finalColor += rippleGlow * baseColor;

    // Blend with original video if requested
    let blendedColor = mix(finalColor, videoColor.rgb, uniforms.u_blend);

    return vec4<f32>(blendedColor, 1.0);
}
