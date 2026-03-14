// Canvas 2D ASCII Renderer
// Takes Zig's per-cell output [charIdx, r, g, b] and renders via Canvas 2D

// Standard character set — matches Zig's Charset.standard
const CHARSETS = {
  standard: ' .:-=+*#%@',
  blocks: ' \u2591\u2592\u2593\u2588',
  minimal: ' .oO@',
  binary: ' \u2588',
  detailed: " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
  dots: ' \u00B7\u2022\u25CF',
  arrows: ' \u2190\u2199\u2193\u2198\u2192\u2197\u2191\u2196',
};

export class AsciiCanvasRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.charset = CHARSETS.standard;
    this.fontSize = 10;
    this.fontFamily = "'JetBrains Mono', 'Fira Code', monospace";
    this.bgColor = '#000000';
    this.cols = 0;
    this.rows = 0;
  }

  // Configure the renderer for given grid dimensions
  configure(cols, rows, fontSize) {
    this.cols = cols;
    this.rows = rows;
    this.fontSize = fontSize;

    // Character cell dimensions
    const charWidth = fontSize * 0.6;
    const charHeight = fontSize;

    // Size canvas to fit the grid
    this.canvas.width = Math.ceil(cols * charWidth);
    this.canvas.height = Math.ceil(rows * charHeight);

    // Configure text rendering
    this.ctx.font = `${fontSize}px ${this.fontFamily}`;
    this.ctx.textBaseline = 'top';

    this.charWidth = charWidth;
    this.charHeight = charHeight;
  }

  // Set the active character set
  setCharset(name) {
    if (CHARSETS[name]) {
      this.charset = CHARSETS[name];
    }
  }

  // Render a frame from WASM output buffer
  // buffer: Uint8Array of [charIdx, r, g, b] per cell
  renderFrame(buffer) {
    if (!buffer || !this.cols || !this.rows) return;

    const ctx = this.ctx;
    const cols = this.cols;
    const rows = this.rows;
    const cw = this.charWidth;
    const ch = this.charHeight;
    const charset = this.charset;
    const charCount = charset.length;

    // Clear canvas
    ctx.fillStyle = this.bgColor;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Set font once
    ctx.font = `${this.fontSize}px ${this.fontFamily}`;
    ctx.textBaseline = 'top';

    // Render each cell
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        const idx = (row * cols + col) * 4;
        const charIdx = Math.min(buffer[idx], charCount - 1);
        const r = buffer[idx + 1];
        const g = buffer[idx + 2];
        const b = buffer[idx + 3];

        // Skip space characters for performance
        if (charIdx === 0 && r === 0 && g === 0 && b === 0) continue;

        const ch_char = charset[charIdx] || ' ';
        const x = col * cw;
        const y = row * ch;

        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.fillText(ch_char, x, y);
      }
    }
  }
}
