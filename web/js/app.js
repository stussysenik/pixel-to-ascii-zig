// Main app orchestrator
// Wires together WASM bridge, canvas renderer, drag & drop, and controls

import { WasmBridge } from './wasm-bridge.js';
import { AsciiCanvasRenderer } from './renderer.js';
import { DragDropHandler } from './drag-drop.js';

class App {
  constructor() {
    this.wasm = new WasmBridge();
    this.renderer = null;
    this.video = null;
    this.offscreenCanvas = null;
    this.offscreenCtx = null;
    this.animationId = null;
    this.playing = false;

    // Default settings
    this.settings = {
      cols: 80,
      fontSize: 10,
      colored: true,
      blend: 0.0,
      highlight: 0.0,
      brightness: 1.0,
      charset: 'standard',
      mouseGlow: true,
      clickRipple: true,
    };
  }

  async start() {
    // Load WASM module
    const wasmUrl = this._resolveWasmUrl();
    const loaded = await this.wasm.load(wasmUrl);

    if (!loaded) {
      console.warn('WASM not available — running in demo mode');
    }

    // Set up drop zone
    const dropZone = document.getElementById('drop-zone');
    if (dropZone) {
      new DragDropHandler(dropZone, (file) => this._onVideoFile(file));
    }

    // Set up ASCII canvas renderer
    const canvas = document.getElementById('ascii-canvas');
    if (canvas) {
      this.renderer = new AsciiCanvasRenderer(canvas);
    }

    // Set up controls
    this._bindControls();

    // Set up mouse tracking on canvas container
    this._bindMouseEvents();
  }

  _resolveWasmUrl() {
    // Try multiple paths for the WASM file
    const paths = [
      '../zig-out/pixel-to-ascii-wasm.wasm',
      '../dist/pixel-to-ascii-wasm.wasm',
      './pixel-to-ascii-wasm.wasm',
    ];
    // Return first path — the bridge handles fetch failure
    return paths[0];
  }

  _onVideoFile(file) {
    // Create object URL and load into hidden video
    const url = URL.createObjectURL(file);

    // Get or create hidden video element
    if (!this.video) {
      this.video = document.createElement('video');
      this.video.muted = true;
      this.video.loop = true;
      this.video.playsInline = true;
      this.video.style.display = 'none';
      document.body.appendChild(this.video);
    }

    this.video.src = url;
    this.video.addEventListener('loadedmetadata', () => {
      this._initRenderer();
      this.video.play();
      this.playing = true;
      this._showPlayer();
      this._startRenderLoop();
    }, { once: true });
  }

  _initRenderer() {
    const vw = this.video.videoWidth;
    const vh = this.video.videoHeight;
    const cols = this.settings.cols;
    const fontSize = this.settings.fontSize;

    // Initialize WASM renderer
    if (this.wasm.initialized) {
      this.wasm.cleanup();
    }
    this.wasm.init(vw, vh, cols, fontSize);

    // Set up offscreen canvas for frame extraction
    this.offscreenCanvas = document.createElement('canvas');
    this.offscreenCanvas.width = vw;
    this.offscreenCanvas.height = vh;
    this.offscreenCtx = this.offscreenCanvas.getContext('2d', { willReadFrequently: true });

    // Configure ASCII renderer
    const gridCols = this.wasm.getGridCols();
    const gridRows = this.wasm.getGridRows();
    if (this.renderer && gridCols > 0 && gridRows > 0) {
      this.renderer.configure(gridCols, gridRows, fontSize);
      this.renderer.setCharset(this.settings.charset);
    }

    // Apply current options
    this.wasm.setOptions(
      this.settings.colored,
      this.settings.blend,
      this.settings.highlight,
      this.settings.brightness
    );
  }

  _showPlayer() {
    const dropContainer = document.getElementById('drop-zone-container');
    const playerContainer = document.getElementById('player-container');
    if (dropContainer) dropContainer.classList.add('hidden');
    if (playerContainer) playerContainer.classList.remove('hidden');

    // Animate panel in
    const panel = document.querySelector('.control-panel');
    if (panel) {
      panel.classList.remove('entering');
      panel.classList.add('visible');
    }
  }

  _startRenderLoop() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }

    const loop = () => {
      if (!this.playing) return;

      // Extract current video frame
      if (this.video && !this.video.paused && this.offscreenCtx) {
        this.offscreenCtx.drawImage(
          this.video, 0, 0,
          this.offscreenCanvas.width,
          this.offscreenCanvas.height
        );

        const imageData = this.offscreenCtx.getImageData(
          0, 0,
          this.offscreenCanvas.width,
          this.offscreenCanvas.height
        );

        // Send frame to WASM
        this.wasm.updateFrame(
          imageData.data,
          this.offscreenCanvas.width,
          this.offscreenCanvas.height
        );
      }

      // Render ASCII
      const output = this.wasm.render();
      if (output && this.renderer) {
        this.renderer.renderFrame(output);
      }

      // Update stats
      this._updateStats();

      this.animationId = requestAnimationFrame(loop);
    };

    this.animationId = requestAnimationFrame(loop);
  }

  _updateStats() {
    const stats = this.wasm.getStats();
    const fpsEl = document.getElementById('stat-fps');
    const ftEl = document.getElementById('stat-frametime');
    const gridEl = document.getElementById('stat-grid');

    if (fpsEl) fpsEl.textContent = `${Math.round(stats.fps)} FPS`;
    if (ftEl) ftEl.textContent = `${stats.frameTime.toFixed(1)}ms`;
    if (gridEl) {
      const cols = this.wasm.getGridCols();
      const rows = this.wasm.getGridRows();
      gridEl.textContent = `${cols}x${rows}`;
    }
  }

  _bindControls() {
    // Columns slider
    this._bindSlider('cols-slider', 'cols-value', (val) => {
      this.settings.cols = parseInt(val);
      if (this.video) this._initRenderer();
    });

    // Brightness slider
    this._bindSlider('brightness-slider', 'brightness-value', (val) => {
      this.settings.brightness = parseFloat(val);
      this.wasm.setOptions(
        this.settings.colored, this.settings.blend,
        this.settings.highlight, this.settings.brightness
      );
    });

    // Blend slider
    this._bindSlider('blend-slider', 'blend-value', (val) => {
      this.settings.blend = parseFloat(val) / 100;
      this.wasm.setOptions(
        this.settings.colored, this.settings.blend,
        this.settings.highlight, this.settings.brightness
      );
    });

    // Highlight slider
    this._bindSlider('highlight-slider', 'highlight-value', (val) => {
      this.settings.highlight = parseFloat(val) / 100;
      this.wasm.setOptions(
        this.settings.colored, this.settings.blend,
        this.settings.highlight, this.settings.brightness
      );
    });

    // Colored toggle
    this._bindToggle('colored-toggle', (active) => {
      this.settings.colored = active;
      this.wasm.setOptions(
        this.settings.colored, this.settings.blend,
        this.settings.highlight, this.settings.brightness
      );
    });

    // Mouse glow toggle
    this._bindToggle('mouse-toggle', (active) => {
      this.settings.mouseGlow = active;
    });

    // Click ripple toggle
    this._bindToggle('ripple-toggle', (active) => {
      this.settings.clickRipple = active;
    });

    // Charset select
    const charsetSelect = document.getElementById('charset-select');
    if (charsetSelect) {
      charsetSelect.addEventListener('change', (e) => {
        this.settings.charset = e.target.value;
        if (this.renderer) this.renderer.setCharset(e.target.value);
      });
    }

    // Play/pause button
    const playBtn = document.getElementById('play-btn');
    if (playBtn) {
      playBtn.addEventListener('click', () => {
        if (!this.video) return;
        if (this.video.paused) {
          this.video.play();
          this.playing = true;
          this._startRenderLoop();
          playBtn.textContent = 'Pause';
        } else {
          this.video.pause();
          this.playing = false;
          playBtn.textContent = 'Play';
        }
      });
    }
  }

  _bindSlider(sliderId, valueId, onChange) {
    const slider = document.getElementById(sliderId);
    const valueEl = document.getElementById(valueId);
    if (!slider) return;

    slider.addEventListener('input', (e) => {
      const val = e.target.value;
      if (valueEl) valueEl.textContent = val;
      onChange(val);
    });
  }

  _bindToggle(toggleId, onChange) {
    const toggle = document.getElementById(toggleId);
    if (!toggle) return;

    toggle.addEventListener('click', () => {
      const active = toggle.classList.toggle('active');
      onChange(active);
    });
  }

  _bindMouseEvents() {
    const container = document.getElementById('canvas-container');
    if (!container) return;

    container.addEventListener('mousemove', (e) => {
      if (!this.settings.mouseGlow || !this.wasm.initialized) return;
      const rect = container.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      this.wasm.updateMouse(x, y);
    });

    container.addEventListener('mouseleave', () => {
      if (this.wasm.initialized) {
        this.wasm.updateMouse(-1, -1);
      }
    });

    container.addEventListener('click', (e) => {
      if (!this.settings.clickRipple || !this.wasm.initialized) return;
      const rect = container.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width;
      const y = (e.clientY - rect.top) / rect.height;
      this.wasm.addRipple(x, y);
    });
  }
}

// Boot
const app = new App();
app.start();
