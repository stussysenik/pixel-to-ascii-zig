// Canvas 2D ASCII renderer
// Consumes Zig's [charIdx, r, g, b] buffer and paints a styled console output.

const CHARSETS = {
  standard: Array.from(' .:-=+*#%@'),
  blocks: Array.from(' \u2591\u2592\u2593\u2588'),
  minimal: Array.from(' .oO@'),
  binary: Array.from(' \u2588'),
  detailed: Array.from(" .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"),
  dots: Array.from(' \u00B7\u2022\u25CF'),
  arrows: Array.from(' \u2190\u2199\u2193\u2198\u2192\u2197\u2191\u2196'),
};

export class AsciiCanvasRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.charset = CHARSETS.standard;
    this.fontSize = 10;
    this.fontFamily = "'IBM Plex Mono', 'SFMono-Regular', monospace";
    this.bgColor = '#000000';
    this.cols = 0;
    this.rows = 0;
    this.charWidth = 0;
    this.charHeight = 0;
  }

  configure(cols, rows, fontSize) {
    this.cols = cols;
    this.rows = rows;
    this.fontSize = fontSize;

    this.charWidth = fontSize * 0.6;
    this.charHeight = fontSize;

    this.canvas.width = Math.ceil(cols * this.charWidth);
    this.canvas.height = Math.ceil(rows * this.charHeight);

    this.ctx.font = `${fontSize}px ${this.fontFamily}`;
    this.ctx.textBaseline = 'top';
    this.ctx.textAlign = 'left';
  }

  setCharset(name) {
    if (CHARSETS[name]) {
      this.charset = CHARSETS[name];
    }
  }

  renderFrame(buffer) {
    if (!buffer || !this.cols || !this.rows) {
      return;
    }

    const { ctx, cols, rows, charWidth, charHeight } = this;
    const charset = this.charset;
    const charCount = charset.length;

    ctx.fillStyle = this.bgColor;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.font = `${this.fontSize}px ${this.fontFamily}`;
    ctx.textBaseline = 'top';

    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < cols; col += 1) {
        const idx = (row * cols + col) * 4;
        const charIdx = Math.min(buffer[idx], charCount - 1);
        const r = buffer[idx + 1];
        const g = buffer[idx + 2];
        const b = buffer[idx + 3];

        if (charIdx === 0 && r === 0 && g === 0 && b === 0) {
          continue;
        }

        const glyph = charset[charIdx] || ' ';
        ctx.fillStyle = `rgb(${r},${g},${b})`;
        ctx.fillText(glyph, col * charWidth, row * charHeight);
      }
    }
  }
}
