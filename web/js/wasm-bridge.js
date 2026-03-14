// WASM Bridge — loads and interfaces with the Zig WASM module
// Manages shared memory between JavaScript and WebAssembly

export class WasmBridge {
  constructor() {
    this.instance = null;
    this.memory = null;
    this.initialized = false;
  }

  // Load and instantiate the WASM module
  async load(wasmUrl) {
    // Shared memory for WASM — 256 pages initial (16MB), 1024 max (64MB)
    this.memory = new WebAssembly.Memory({ initial: 256, maximum: 1024 });

    const importObject = {
      env: {
        memory: this.memory,
      },
      // Zig's WASM output may import these
      wasi_snapshot_preview1: {
        fd_write: () => 0,
        fd_close: () => 0,
        fd_seek: () => 0,
        proc_exit: () => {},
        clock_time_get: (id, precision, out) => {
          const view = new DataView(this.memory.buffer);
          const now = BigInt(Date.now()) * 1000000n;
          view.setBigUint64(out, now, true);
          return 0;
        },
      },
    };

    try {
      const response = await fetch(wasmUrl);
      const bytes = await response.arrayBuffer();
      const result = await WebAssembly.instantiate(bytes, importObject);
      this.instance = result.instance;
      return true;
    } catch (err) {
      console.error('WASM load failed:', err);
      return false;
    }
  }

  // Initialize the renderer
  init(width, height, cols, fontSize) {
    if (!this.instance) return false;
    const ok = this.instance.exports.init(width, height, cols, fontSize);
    this.initialized = ok;
    return ok;
  }

  // Copy RGBA frame data into WASM memory and call updateVideoFrame
  updateFrame(rgbaData, width, height) {
    if (!this.initialized) return false;

    const stride = width * 4;
    const byteLength = rgbaData.byteLength;

    // Write frame data to WASM memory at a known offset
    // We'll use the area after the existing allocations
    const wasmMemory = new Uint8Array(this.memory.buffer);
    const frameOffset = this.memory.buffer.byteLength - byteLength;

    // Ensure memory is large enough
    if (frameOffset < 0) {
      const pagesNeeded = Math.ceil(byteLength / 65536) + 1;
      try {
        this.memory.grow(pagesNeeded);
      } catch {
        return false;
      }
    }

    // Copy frame data
    new Uint8Array(this.memory.buffer, frameOffset, byteLength).set(
      new Uint8Array(rgbaData.buffer || rgbaData)
    );

    return this.instance.exports.updateVideoFrame(frameOffset, width, height, stride);
  }

  // Call render and return the output buffer as a typed array view
  render() {
    if (!this.initialized) return null;

    const ptr = this.instance.exports.render();
    if (!ptr) return null;

    const cols = this.instance.exports.getGridCols();
    const rows = this.instance.exports.getGridRows();
    const size = cols * rows * 4;

    return new Uint8Array(this.memory.buffer, ptr, size);
  }

  // Get grid dimensions
  getGridCols() {
    if (!this.initialized) return 0;
    return this.instance.exports.getGridCols();
  }

  getGridRows() {
    if (!this.initialized) return 0;
    return this.instance.exports.getGridRows();
  }

  // Get packed stats (fps and frame_time packed into u64)
  getStats() {
    if (!this.initialized) return { fps: 0, frameTime: 0 };
    const packed = this.instance.exports.getStats();
    const buf = new ArrayBuffer(8);
    const view = new DataView(buf);
    // packed is a BigInt from wasm i64
    if (typeof packed === 'bigint') {
      view.setBigUint64(0, packed, true);
    } else {
      view.setUint32(0, packed & 0xFFFFFFFF, true);
      view.setUint32(4, (packed >>> 32) & 0xFFFFFFFF, true);
    }
    return {
      fps: view.getFloat32(0, true),
      frameTime: view.getFloat32(4, true),
    };
  }

  // Pass-through to WASM exports
  setOptions(colored, blend, highlight, brightness) {
    if (!this.initialized) return;
    this.instance.exports.setOptions(colored, blend, highlight, brightness);
  }

  updateMouse(x, y) {
    if (!this.initialized) return;
    this.instance.exports.updateMouse(x, y);
  }

  addRipple(x, y) {
    if (!this.initialized) return;
    this.instance.exports.addRipple(x, y);
  }

  updateAudio(level, reactivity, sensitivity) {
    if (!this.initialized) return;
    this.instance.exports.updateAudio(level, reactivity, sensitivity);
  }

  cleanup() {
    if (!this.initialized) return;
    this.instance.exports.cleanup();
    this.initialized = false;
  }
}
