/**
 * pixel-to-ascii — C API
 *
 * High-performance video-to-ASCII converter powered by Zig.
 * This header provides the C-compatible interface for native consumers
 * (SwiftUI, Objective-C, C++, etc.).
 *
 * Build the static library:
 *   zig build macos -Doptimize=ReleaseFast
 *   zig build ios -Doptimize=ReleaseFast
 */

#ifndef PIXEL_TO_ASCII_H
#define PIXEL_TO_ASCII_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize the ASCII renderer.
 * @param width    Video frame width in pixels
 * @param height   Video frame height in pixels
 * @param num_columns  Number of ASCII columns in output grid
 * @param font_size    Font size (used for aspect ratio calculation)
 * @return true on success, false on allocation failure
 */
bool pta_init(uint32_t width, uint32_t height, uint32_t num_columns, float font_size);

/**
 * Upload a new video frame (RGBA format).
 * @param data    Pointer to RGBA pixel data
 * @param width   Frame width in pixels
 * @param height  Frame height in pixels
 * @param stride  Row stride in bytes (typically width * 4)
 * @return true on success
 */
bool pta_update_video_frame(const uint8_t* data, uint32_t width, uint32_t height, uint32_t stride);

/**
 * Render the current frame to ASCII.
 * @return Pointer to output buffer: [char_index, r, g, b] per cell.
 *         Buffer size = pta_get_grid_cols() * pta_get_grid_rows() * 4 bytes.
 *         Returns NULL if renderer is not initialized.
 */
const uint8_t* pta_render(void);

/** @return Number of columns in the ASCII grid */
uint32_t pta_get_grid_cols(void);

/** @return Number of rows in the ASCII grid */
uint32_t pta_get_grid_rows(void);

/**
 * Set rendering options.
 * @param colored     Enable color output (vs monochrome)
 * @param blend       Color blend factor (0.0 - 1.0)
 * @param highlight   Highlight intensity for bright areas (0.0 - 1.0)
 * @param brightness  Brightness multiplier (0.2 - 3.0)
 */
void pta_set_options(bool colored, float blend, float highlight, float brightness);

/**
 * Update mouse position for glow effect.
 * @param x  Normalized X (0.0 - 1.0), -1 to disable
 * @param y  Normalized Y (0.0 - 1.0), -1 to disable
 */
void pta_update_mouse(float x, float y);

/**
 * Add a click ripple effect at position.
 * @param x  Normalized X (0.0 - 1.0)
 * @param y  Normalized Y (0.0 - 1.0)
 */
void pta_add_ripple(float x, float y);

/**
 * Clean up and free all resources.
 * Call this when done with the renderer.
 */
void pta_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* PIXEL_TO_ASCII_H */
