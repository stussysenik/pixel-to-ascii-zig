// WASM bridge for the Zig renderer.
// Loads the module, manages shared memory, and exposes a stable JS API.

export class WasmBridge {
  constructor() {
    this.instance = null;
    this.memory = null;
    this.initialized = false;
    this.loadedUrl = null;
  }

  async load(wasmUrls) {
    const candidates = Array.isArray(wasmUrls) ? wasmUrls : [wasmUrls];

    this.memory = new WebAssembly.Memory({ initial: 256, maximum: 1024 });

    const importObject = {
      env: {
        memory: this.memory,
      },
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

    let lastError = null;

    for (const candidate of candidates) {
      try {
        const url = candidate instanceof URL ? candidate : new URL(candidate, window.location.href);
        const response = await fetch(url);

        if (!response.ok) {
          throw new Error(`HTTP ${response.status} for ${url.href}`);
        }

        const bytes = await response.arrayBuffer();
        const result = await WebAssembly.instantiate(bytes, importObject);
        this.instance = result.instance;
        this.loadedUrl = url.href;
        return true;
      } catch (error) {
        lastError = error;
      }
    }

    console.error('WASM load failed:', lastError);
    return false;
  }

  init(width, height, cols, fontSize) {
    if (!this.instance) {
      return false;
    }

    const ok = this.instance.exports.init(width, height, cols, fontSize);
    this.initialized = ok;
    return ok;
  }

  updateFrame(rgbaData, width, height) {
    if (!this.initialized) {
      return false;
    }

    const stride = width * 4;
    const byteLength = rgbaData.byteLength;

    let frameOffset = this.memory.buffer.byteLength - byteLength;
    if (frameOffset < 0) {
      const deficit = byteLength - this.memory.buffer.byteLength;
      const pagesNeeded = Math.ceil(deficit / 65536) + 1;

      try {
        this.memory.grow(pagesNeeded);
      } catch {
        return false;
      }

      frameOffset = this.memory.buffer.byteLength - byteLength;
    }

    const source = rgbaData instanceof Uint8ClampedArray ? rgbaData : new Uint8Array(rgbaData.buffer || rgbaData);
    new Uint8Array(this.memory.buffer, frameOffset, byteLength).set(source);

    return this.instance.exports.updateVideoFrame(frameOffset, width, height, stride);
  }

  render() {
    if (!this.initialized) {
      return null;
    }

    const ptr = this.instance.exports.render();
    if (!ptr) {
      return null;
    }

    const cols = this.instance.exports.getGridCols();
    const rows = this.instance.exports.getGridRows();
    const size = cols * rows * 4;

    return new Uint8Array(this.memory.buffer, ptr, size);
  }

  getGridCols() {
    return this.initialized ? this.instance.exports.getGridCols() : 0;
  }

  getGridRows() {
    return this.initialized ? this.instance.exports.getGridRows() : 0;
  }

  getStats() {
    if (!this.initialized) {
      return { fps: 0, frameTime: 0 };
    }

    const packed = this.instance.exports.getStats();
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);

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

  setOptions(colored, blend, highlight, brightness) {
    if (!this.initialized) {
      return;
    }

    this.instance.exports.setOptions(colored, blend, highlight, brightness);
  }

  updateMouse(x, y) {
    if (!this.initialized) {
      return;
    }

    this.instance.exports.updateMouse(x, y);
  }

  addRipple(x, y) {
    if (!this.initialized) {
      return;
    }

    this.instance.exports.addRipple(x, y);
  }

  updateAudio(level, reactivity, sensitivity) {
    if (!this.initialized) {
      return;
    }

    this.instance.exports.updateAudio(level, reactivity, sensitivity);
  }

  cleanup() {
    if (!this.initialized) {
      return;
    }

    this.instance.exports.cleanup();
    this.initialized = false;
  }
}
