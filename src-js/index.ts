/**
 * TypeScript interface for the Zig WASM module
 * Provides type safety for JavaScript/TypeScript interop with the WebAssembly module
 */

/**
 * Grid dimensions for ASCII output
 */
export interface GridDimensions {
  /** Number of columns in the ASCII grid */
  cols: number;
  /** Number of rows in the ASCII grid */
  rows: number;
}

/**
 * Performance statistics from the renderer
 */
export interface Stats {
  /** Current frames per second */
  fps: number;
  /** Frame render time in milliseconds */
  frame_time_ms: number;
}

/**
 * Rendering configuration options
 */
export interface RenderOptions {
  /** Whether to use colored output or green terminal style */
  colored?: boolean;
  /** Blend with original video (0.0 = pure ASCII, 1.0 = pure video) */
  blend?: number;
  /** Background highlight intensity (0.0 - 1.0) */
  highlight?: number;
  /** Brightness multiplier (1.0 = normal, <1.0 = darker, >1.0 = brighter) */
  brightness?: number;
}

/**
 * Audio effect configuration
 */
export interface AudioConfig {
  /** Current audio level (0.0 - 1.0) */
  level: number;
  /** Audio reactivity strength (0.0 - 1.0) */
  reactivity: number;
  /** Audio sensitivity (0.0 - 1.0) */
  sensitivity: number;
}

/**
 * Configuration for initializing the ASCII renderer
 */
export interface InitConfig {
  /** Output width in pixels */
  width: number;
  /** Output height in pixels */
  height: number;
  /** Number of columns in the ASCII grid */
  num_columns: number;
  /** Font size for characters in pixels */
  font_size?: number;
}

/**
 * WebAssembly memory view for accessing buffers
 */
export interface WasmMemory {
  /** Byte-length of the memory */
  byteLength: number;
  /** Raw buffer */
  buffer: ArrayBuffer;
}

/**
 * Instance interface for the pixel-to-ascii WASM module
 */
export interface PixelToAsciiWasmModule {
  // Core functions

  /**
   * Initialize the ASCII renderer
   * @param width - Output width in pixels
   * @param height - Output height in pixels
   * @param num_columns - Number of ASCII columns
   * @param font_size - Font size in pixels (default: 10.0)
   * @returns true if initialization succeeded, false otherwise
   */
  init(width: number, height: number, num_columns: number, font_size?: number): boolean;

  /**
   * Update the video frame from a raw RGBA buffer
   * @param data - Pointer to RGBA pixel data (or Uint8Array)
   * @param width - Video frame width
   * @param height - Video frame height
   * @param stride - Bytes per row (usually width * 4)
   * @returns true if update succeeded, false otherwise
   */
  updateVideoFrame(data: number | Uint8Array, width: number, height: number, stride: number): boolean;

  /**
   * Update mouse position for glow effect
   * @param x - Normalized X coordinate (0.0 - 1.0)
   * @param y - Normalized Y coordinate (0.0 - 1.0)
   */
  updateMouse(x: number, y: number): void;

  /**
   * Update audio level for reactivity effect
   * @param level - Audio level (0.0 - 1.0)
   * @param reactivity - Audio reactivity strength (0.0 - 1.0)
   * @param sensitivity - Audio sensitivity (0.0 - 1.0)
   */
  updateAudio(level: number, reactivity: number, sensitivity: number): void;

  /**
   * Add a ripple effect at the specified position
   * @param x - Normalized X coordinate (0.0 - 1.0)
   * @param y - Normalized Y coordinate (0.0 - 1.0)
   */
  addRipple(x: number, y: number): void;

  /**
   * Set rendering options
   * @param colored - Whether to use colored output
   * @param blend - Blend with original video (0.0 - 1.0)
   * @param highlight - Background highlight intensity (0.0 - 1.0)
   * @param brightness - Brightness multiplier (1.0 = normal)
   */
  setOptions(colored: boolean, blend: number, highlight: number, brightness: number): void;

  /**
   * Render a frame
   * @returns Pointer to the output RGBA buffer
   */
  render(): number;

  /**
   * Get the size of the output buffer in bytes
   * @returns Buffer size in bytes
   */
  getOutputBufferSize(): number;

  /**
   * Get the grid dimensions
   * @returns Grid dimensions object
   */
  getGridDimensions(): GridDimensions;

  /**
   * Get performance statistics
   * @returns Performance statistics object
   */
  getStats(): Stats;

  /**
   * Cleanup and free all resources
   */
  cleanup(): void;

  // WebAssembly exports

  /**
   * WebAssembly memory object
   */
  memory?: WasmMemory;
}

/**
 * Initialize the pixel-to-ascii WASM module
 * @param wasmBytes - WebAssembly binary data
 * @param memory - Optional WebAssembly memory (will be created if not provided)
 * @returns Promise resolving to the initialized WASM module
 */
export async function initPixelToAsciiWasm(
  wasmBytes: ArrayBuffer | Uint8Array,
  memory?: WebAssembly.Memory
): Promise<PixelToAsciiWasmModule> {
  const wasmModule = await WebAssembly.instantiate(
    wasmBytes,
    memory ? { env: { memory } } : undefined
  );

  const instance = wasmModule.instance;
  const exports = instance.exports as unknown as PixelToAsciiWasmModule;

  // Attach memory if provided
  if (memory) {
    exports.memory = {
      byteLength: memory.buffer.byteLength,
      buffer: memory.buffer,
    };
  } else if ('memory' in instance.exports) {
    const wasmMemory = instance.exports.memory as WebAssembly.Memory;
    exports.memory = {
      byteLength: wasmMemory.buffer.byteLength,
      buffer: wasmMemory.buffer,
    };
  }

  return exports;
}

/**
 * Helper to read the output buffer from WASM
 * @param module - The WASM module instance
 * @returns Uint8Array containing the RGBA pixel data
 */
export function readOutputBuffer(module: PixelToAsciiWasmModule): Uint8Array {
  const pointer = module.render();
  const size = module.getOutputBufferSize();

  if (!module.memory) {
    throw new Error('WASM memory not available');
  }

  const data = new Uint8Array(module.memory.buffer, pointer, size);
  return new Uint8Array(data);
}

/**
 * Helper to write video frame to WASM
 * @param module - The WASM module instance
 * @param frameData - RGBA pixel data as Uint8Array
 * @param width - Frame width
 * @param height - Frame height
 * @returns true if successful
 */
export function writeVideoFrame(
  module: PixelToAsciiWasmModule,
  frameData: Uint8Array,
  width: number,
  height: number
): boolean {
  if (!module.memory) {
    throw new Error('WASM memory not available');
  }

  const stride = width * 4;
  const requiredSize = frameData.length;

  // Allocate space in WASM memory
  const pointer = module.getOutputBufferSize() + 1024; // Simple allocation strategy

  // Copy frame data to WASM memory
  const wasmData = new Uint8Array(module.memory.buffer, pointer, requiredSize);
  wasmData.set(frameData);

  return module.updateVideoFrame(pointer, width, height, stride);
}

// Export default
export default PixelToAsciiWasmModule;
