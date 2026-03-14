// Main app orchestrator.
// Wires the Zig WASM bridge into the browser UI and supports image + video assets.

import { WasmBridge } from './wasm-bridge.js';
import { AsciiCanvasRenderer } from './renderer.js';
import { DragDropHandler } from './drag-drop.js';

class App {
  constructor() {
    this.wasm = new WasmBridge();
    this.renderer = null;

    this.video = null;
    this.image = null;
    this.currentSource = null;
    this.currentFile = null;
    this.assetType = null;
    this.currentObjectUrl = null;

    this.offscreenCanvas = null;
    this.offscreenCtx = null;
    this.animationId = null;
    this.rendering = false;

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
    const loaded = await this.wasm.load(this._resolveWasmUrls());
    this._setRuntimeStatus(loaded ? 'WASM live' : 'WASM unavailable');
    this._setSignalMessage(
      loaded
        ? 'Console ready for still or motion ingestion'
        : 'Build `zig build wasm -Doptimize=ReleaseFast` and reload'
    );

    const dropZone = document.getElementById('drop-zone');
    if (dropZone) {
      new DragDropHandler(
        dropZone,
        (file) => this._onAssetFile(file),
        (file) => this._handleUnsupportedAsset(file),
      );
    }

    const canvas = document.getElementById('ascii-canvas');
    if (canvas) {
      this.renderer = new AsciiCanvasRenderer(canvas);
    }

    this._bindControls();
    this._bindMouseEvents();
    this._resetSession({ preserveRuntime: true });
  }

  _resolveWasmUrls() {
    return [
      new URL('../../zig-out/pixel-to-ascii-wasm.wasm', import.meta.url),
      new URL('../../dist/pixel-to-ascii-wasm.wasm', import.meta.url),
      new URL('../pixel-to-ascii-wasm.wasm', import.meta.url),
    ];
  }

  async _onAssetFile(file) {
    if (!this.wasm.instance) {
      this._setSignalMessage('Renderer unavailable. Build the WASM module first.');
      return;
    }

    if (file.type.startsWith('video/')) {
      await this._loadVideo(file);
      return;
    }

    if (file.type.startsWith('image/')) {
      await this._loadImage(file);
      return;
    }

    this._handleUnsupportedAsset(file);
  }

  _handleUnsupportedAsset(file) {
    this._setAssetStatus('Rejected');
    this._setSignalMessage(`Unsupported asset: ${file.name}`);
    this._setStage('Unsupported asset type', 'Reject');
  }

  async _loadVideo(file) {
    this._resetSession({ preserveRuntime: true, keepDropZone: true });
    this.assetType = 'video';
    this.currentFile = file;
    this.currentObjectUrl = URL.createObjectURL(file);

    const video = this._ensureVideoElement();
    video.src = this.currentObjectUrl;

    await new Promise((resolve, reject) => {
      const onLoaded = () => {
        video.removeEventListener('error', onError);
        resolve();
      };
      const onError = () => {
        video.removeEventListener('loadedmetadata', onLoaded);
        reject(new Error('Video could not be decoded'));
      };

      video.addEventListener('loadedmetadata', onLoaded, { once: true });
      video.addEventListener('error', onError, { once: true });
    }).catch((error) => {
      this._setSignalMessage(error.message);
    });

    if (!video.videoWidth || !video.videoHeight) {
      return;
    }

    this.currentSource = video;
    if (!this._initRenderer()) {
      return;
    }

    try {
      await video.play();
    } catch {
      // Autoplay can fail until the user interacts; rendering still works on demand.
    }

    this._showPlayer();
    this._setAssetStatus('Video armed');
    this._setSignalMessage('Motion feed translated into ASCII cells');
    this._setStage(`${file.name} synchronized`, 'Video');
    this._updateAssetTelemetry();
    this._updateTransportState();
    this._startRenderLoop();
  }

  async _loadImage(file) {
    this._resetSession({ preserveRuntime: true, keepDropZone: true });
    this.assetType = 'image';
    this.currentFile = file;
    this.currentObjectUrl = URL.createObjectURL(file);

    const image = this._ensureImageElement();
    await new Promise((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = () => reject(new Error('Image could not be decoded'));
      image.src = this.currentObjectUrl;
    }).catch((error) => {
      this._setSignalMessage(error.message);
    });

    if (!image.naturalWidth || !image.naturalHeight) {
      return;
    }

    this.currentSource = image;
    if (!this._initRenderer()) {
      return;
    }

    this._showPlayer();
    this._setAssetStatus('Still latched');
    this._setSignalMessage('Still frame resolved into ASCII raster');
    this._setStage(`${file.name} resolved`, 'Still');
    this._updateAssetTelemetry();
    this._updateTransportState();
    this._startRenderLoop();
  }

  _ensureVideoElement() {
    if (!this.video) {
      this.video = document.createElement('video');
      this.video.muted = true;
      this.video.loop = true;
      this.video.playsInline = true;
      this.video.preload = 'auto';
      this.video.style.display = 'none';
      document.body.appendChild(this.video);
    }

    return this.video;
  }

  _ensureImageElement() {
    if (!this.image) {
      this.image = document.createElement('img');
      this.image.alt = '';
      this.image.decoding = 'async';
      this.image.style.display = 'none';
      document.body.appendChild(this.image);
    }

    return this.image;
  }

  _initRenderer() {
    const dimensions = this._getSourceDimensions();
    if (!dimensions || !this.wasm.instance) {
      return false;
    }

    if (this.wasm.initialized) {
      this.wasm.cleanup();
    }

    const initialized = this.wasm.init(
      dimensions.width,
      dimensions.height,
      this.settings.cols,
      this.settings.fontSize,
    );

    if (!initialized) {
      this._setSignalMessage('Renderer failed to initialize');
      return false;
    }

    if (!this.offscreenCanvas) {
      this.offscreenCanvas = document.createElement('canvas');
    }

    this.offscreenCanvas.width = dimensions.width;
    this.offscreenCanvas.height = dimensions.height;
    this.offscreenCtx = this.offscreenCanvas.getContext('2d', { willReadFrequently: true });

    const gridCols = this.wasm.getGridCols();
    const gridRows = this.wasm.getGridRows();

    if (this.renderer && gridCols > 0 && gridRows > 0) {
      this.renderer.configure(gridCols, gridRows, this.settings.fontSize);
      this.renderer.setCharset(this.settings.charset);
    }

    this.wasm.setOptions(
      this.settings.colored,
      this.settings.blend,
      this.settings.highlight,
      this.settings.brightness,
    );

    this._updateAssetTelemetry();
    this._updateStats(true);
    return true;
  }

  _getSourceDimensions() {
    if (this.assetType === 'video' && this.video) {
      return {
        width: this.video.videoWidth,
        height: this.video.videoHeight,
      };
    }

    if (this.assetType === 'image' && this.image) {
      return {
        width: this.image.naturalWidth,
        height: this.image.naturalHeight,
      };
    }

    return null;
  }

  _showPlayer() {
    document.getElementById('drop-zone-container')?.classList.add('hidden');
    document.getElementById('player-container')?.classList.remove('hidden');
  }

  _showDropZone() {
    document.getElementById('drop-zone-container')?.classList.remove('hidden');
    document.getElementById('player-container')?.classList.add('hidden');
  }

  _startRenderLoop() {
    this.rendering = true;
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }

    const loop = () => {
      if (!this.rendering) {
        return;
      }

      this._renderFrame();
      this.animationId = requestAnimationFrame(loop);
    };

    this.animationId = requestAnimationFrame(loop);
  }

  _stopRenderLoop() {
    this.rendering = false;

    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  _renderFrame() {
    if (!this.offscreenCtx || !this.offscreenCanvas || !this.currentSource || !this.wasm.initialized) {
      return;
    }

    const canDrawVideo = this.assetType !== 'video' || (this.video && this.video.readyState >= 2);
    if (!canDrawVideo) {
      return;
    }

    this.offscreenCtx.drawImage(
      this.currentSource,
      0,
      0,
      this.offscreenCanvas.width,
      this.offscreenCanvas.height,
    );

    const imageData = this.offscreenCtx.getImageData(
      0,
      0,
      this.offscreenCanvas.width,
      this.offscreenCanvas.height,
    );

    this.wasm.updateFrame(
      imageData.data,
      this.offscreenCanvas.width,
      this.offscreenCanvas.height,
    );

    const output = this.wasm.render();
    if (output && this.renderer) {
      this.renderer.renderFrame(output);
    }

    this._updateStats();
  }

  _updateStats(force = false) {
    const stats = this.wasm.initialized ? this.wasm.getStats() : { fps: 0, frameTime: 0 };
    const cols = this.wasm.initialized ? this.wasm.getGridCols() : 0;
    const rows = this.wasm.initialized ? this.wasm.getGridRows() : 0;

    document.getElementById('stat-fps').textContent = force || !stats.fps
      ? '-- FPS'
      : `${Math.round(stats.fps)} FPS`;
    document.getElementById('stat-frametime').textContent = force || !stats.frameTime
      ? '-- ms'
      : `${stats.frameTime.toFixed(1)} ms`;
    document.getElementById('stat-grid').textContent = cols && rows ? `${cols} x ${rows}` : '-- x --';
    document.getElementById('asset-grid-readout').textContent = cols && rows ? `${cols} x ${rows}` : '-- x --';
  }

  _updateAssetTelemetry() {
    const dimensions = this._getSourceDimensions();
    const assetName = this.currentFile ? this.currentFile.name : 'Awaiting ingest';
    const resolution = dimensions ? `${dimensions.width} x ${dimensions.height}` : '-- x --';

    document.getElementById('asset-name').textContent = assetName;
    document.getElementById('asset-resolution').textContent = resolution;
    document.getElementById('asset-mode-readout').textContent = this._getModeLabel();
  }

  _getModeLabel() {
    if (this.assetType === 'video') {
      return this.video?.paused ? 'Video paused' : 'Video live';
    }

    if (this.assetType === 'image') {
      return 'Still frame';
    }

    return 'Idle';
  }

  _setRuntimeStatus(message) {
    const el = document.getElementById('runtime-status');
    if (el) {
      el.textContent = message;
    }
  }

  _setAssetStatus(message) {
    const assetStatus = document.getElementById('asset-status');
    const kindChip = document.getElementById('asset-kind-chip');

    if (assetStatus) {
      assetStatus.textContent = message;
    }

    if (kindChip) {
      kindChip.textContent = message;
    }
  }

  _setSignalMessage(message) {
    const el = document.getElementById('signal-message');
    if (el) {
      el.textContent = message;
    }
  }

  _setStage(title, mode) {
    const titleEl = document.getElementById('stage-title');
    const modeEl = document.getElementById('stage-mode');

    if (titleEl) {
      titleEl.textContent = title;
    }

    if (modeEl) {
      modeEl.textContent = mode;
    }
  }

  _bindControls() {
    this._bindSlider('cols-slider', 'cols-value', (value) => {
      this.settings.cols = Number.parseInt(value, 10);
      if (this.currentSource) {
        this._initRenderer();
      }
    });

    this._bindSlider('brightness-slider', 'brightness-value', (value) => {
      this.settings.brightness = Number.parseFloat(value);
      this._applyOptions();
    });

    this._bindSlider('blend-slider', 'blend-value', (value) => {
      this.settings.blend = Number.parseFloat(value) / 100;
      this._applyOptions();
    });

    this._bindSlider('highlight-slider', 'highlight-value', (value) => {
      this.settings.highlight = Number.parseFloat(value) / 100;
      this._applyOptions();
    });

    this._bindToggle('colored-toggle', (active) => {
      this.settings.colored = active;
      this._applyOptions();
    });

    this._bindToggle('mouse-toggle', (active) => {
      this.settings.mouseGlow = active;
    });

    this._bindToggle('ripple-toggle', (active) => {
      this.settings.clickRipple = active;
    });

    document.getElementById('charset-select')?.addEventListener('change', (event) => {
      this.settings.charset = event.target.value;
      this.renderer?.setCharset(this.settings.charset);
    });

    document.getElementById('play-btn')?.addEventListener('click', async () => {
      if (this.assetType !== 'video' || !this.video) {
        return;
      }

      if (this.video.paused) {
        await this.video.play().catch(() => {});
        this._setSignalMessage('Motion feed resumed');
      } else {
        this.video.pause();
        this._setSignalMessage('Motion feed paused on current frame');
      }

      this._updateTransportState();
      this._updateAssetTelemetry();
    });

    document.getElementById('reset-btn')?.addEventListener('click', () => {
      this._resetSession({ preserveRuntime: true });
    });
  }

  _bindSlider(sliderId, valueId, onChange) {
    const slider = document.getElementById(sliderId);
    const value = document.getElementById(valueId);

    if (!slider) {
      return;
    }

    slider.addEventListener('input', (event) => {
      const nextValue = event.target.value;
      if (value) {
        value.textContent = nextValue;
      }
      onChange(nextValue);
    });
  }

  _bindToggle(toggleId, onChange) {
    const toggle = document.getElementById(toggleId);
    if (!toggle) {
      return;
    }

    toggle.addEventListener('click', () => {
      const active = toggle.classList.toggle('active');
      toggle.setAttribute('aria-checked', String(active));
      onChange(active);
    });
  }

  _bindMouseEvents() {
    const container = document.getElementById('canvas-container');
    if (!container) {
      return;
    }

    container.addEventListener('mousemove', (event) => {
      if (!this.settings.mouseGlow || !this.wasm.initialized) {
        return;
      }

      const rect = container.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width;
      const y = (event.clientY - rect.top) / rect.height;
      this.wasm.updateMouse(x, y);
    });

    container.addEventListener('mouseleave', () => {
      if (this.wasm.initialized) {
        this.wasm.updateMouse(-1, -1);
      }
    });

    container.addEventListener('click', (event) => {
      if (!this.settings.clickRipple || !this.wasm.initialized) {
        return;
      }

      const rect = container.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width;
      const y = (event.clientY - rect.top) / rect.height;
      this.wasm.addRipple(x, y);
    });
  }

  _applyOptions() {
    if (!this.wasm.initialized) {
      return;
    }

    this.wasm.setOptions(
      this.settings.colored,
      this.settings.blend,
      this.settings.highlight,
      this.settings.brightness,
    );
  }

  _updateTransportState() {
    const playButton = document.getElementById('play-btn');
    if (!playButton) {
      return;
    }

    if (this.assetType === 'video' && this.video) {
      playButton.disabled = false;
      playButton.textContent = this.video.paused ? 'Play' : 'Pause';
      return;
    }

    if (this.assetType === 'image') {
      playButton.disabled = true;
      playButton.textContent = 'Still';
      return;
    }

    playButton.disabled = true;
    playButton.textContent = 'Pause';
  }

  _resetSession({ preserveRuntime = false, keepDropZone = false } = {}) {
    this._stopRenderLoop();

    if (this.video) {
      this.video.pause();
      this.video.removeAttribute('src');
      this.video.load();
    }

    if (this.image) {
      this.image.removeAttribute('src');
    }

    if (this.currentObjectUrl) {
      URL.revokeObjectURL(this.currentObjectUrl);
      this.currentObjectUrl = null;
    }

    if (this.wasm.initialized) {
      this.wasm.cleanup();
    }

    this.currentSource = null;
    this.currentFile = null;
    this.assetType = null;

    if (!keepDropZone) {
      this._showDropZone();
    }

    this._setAssetStatus('No signal');
    this._setStage('Stand by for asset ingest', 'Idle');
    this._setSignalMessage('Drag a still or moving asset into the console');
    this._updateAssetTelemetry();
    this._updateTransportState();
    this._updateStats(true);

    if (!preserveRuntime) {
      this._setRuntimeStatus('Booting');
    }
  }
}

const app = new App();
app.start();
