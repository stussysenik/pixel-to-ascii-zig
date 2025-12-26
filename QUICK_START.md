# Quick Start Guide

Get up and running with Pixel to ASCII (Zig/WebGPU) in 5 minutes.

## Prerequisites

Before you begin, ensure you have:

- **Node.js** >= 18.0.0
- **npm** >= 9.0.0
- **Zig** >= 0.12.0 (for building from source)
- **Browser** with WebGPU support:
  - Chrome 113+
  - Edge 113+
  - Firefox 119+ (with `dom.webgpu.enabled` flag)

## Installation

### Option 1: Install from npm (Recommended)

```bash
# Install the package
npm install @zig-wasm/pixel-to-ascii

# Install React (if not already installed)
npm install react react-dom
```

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/pixel-to-ascii-zig.git
cd pixel-to-ascii-zig

# Install dependencies
npm install

# Build the WASM module
npm run build

# The WASM file will be in dist/pixel-to-ascii-wasm.wasm
```

## Basic Usage

### React Component

The easiest way to use Pixel to ASCII is with the React component:

```tsx
import { Video2AsciiZig } from '@zig-wasm/pixel-to-ascii/react';

function App() {
  return (
    <Video2AsciiZig
      src="/path/to/your/video.mp4"
      numColumns={120}
      colored={true}
      enableMouse={true}
      enableRipple={true}
      showStats={true}
    />
  );
}

export default App;
```

That's it! The component will:
- Automatically load the WASM module
- Initialize the renderer when the video loads
- Render ASCII art at 60+ FPS
- Show interactive effects (mouse glow, click ripples)

### Minimal Example

```tsx
import { Video2AsciiZig } from '@zig-wasm/pixel-to-ascii/react';

function MinimalApp() {
  return (
    <Video2AsciiZig
      src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
      numColumns={80}
    />
  );
}
```

## Configuration Options

### Size Control

```tsx
<Video2AsciiZig
  src="/video.mp4"
  numColumns={120}      // Number of ASCII columns (default: 80)
  maxWidth={1920}      // Maximum width in pixels (optional)
/>
```

### Rendering Style

```tsx
<Video2AsciiZig
  src="/video.mp4"
  colored={true}        // Use colored output (default: true)
  blend={10}            // Blend with original video 0-100 (default: 0)
  highlight={20}         // Background highlight 0-100 (default: 0)
  brightness={1.2}       // Brightness multiplier (default: 1.0)
/>
```

### Interactive Effects

```tsx
<Video2AsciiZig
  src="/video.mp4"
  enableMouse={true}    // Mouse glow effect (default: true)
  trailLength={24}      // Trail length 1-24 (default: 24)
  enableRipple={true}   // Click ripple effect (default: false)
  rippleSpeed={40}      // Expansion speed (default: 40)
/>
```

### Audio Reactivity

```tsx
<Video2AsciiZig
  src="/video.mp4"
  audioEffect={70}      // Audio reactivity 0-100 (default: 0)
  audioRange={50}       // Audio sensitivity 0-100 (default: 50)
/>
```

**Note:** For audio effects to work, your video must have audio and the `<video>` element should not be muted.

### Playback Controls

```tsx
<Video2AsciiZig
  src="/video.mp4"
  isPlaying={true}               // Play/pause state (default: true)
  autoPlay={true}                // Auto-start (default: true)
  enableSpacebarToggle={true}     // Spacebar to toggle (default: false)
/>

// Programmatic control
const ref = useRef<Video2AsciiZigRef>(null);

function play() {
  ref.current?.play();
}

function pause() {
  ref.current?.pause();
}

function toggle() {
  ref.current?.toggle();
}

<Video2AsciiZig ref={ref} ... />
```

## Character Sets

Choose from 8 pre-defined character sets:

```tsx
<Video2AsciiZig
  src="/video.mp4"
  charset="standard"  // Options: standard, blocks, minimal, binary, 
                     //         detailed, dots, arrows, emoji
/>
```

### Available Character Sets

| Set | Characters | Description |
|-----|-----------|-------------|
| `standard` | ` .:-=+*#%@` | Classic 10-char gradient |
| `blocks` | ` ░▒▓█` | Unicode block characters |
| `minimal` | ` .oO@` | Minimal 5-char set |
| `binary` | ` █` | Pure silhouette |
| `detailed` | ` .'`^",:;Il!i...` | 70-char max detail |
| `dots` | ` ·•●` | Dot-based |
| `arrows` | ` ←↙↓↘→↗↑↖` | Directional arrows |
| `emoji` | `  ░▒▓🌑🌒🌓🌔🌕` | Moon phases |

## Common Use Cases

### 1. Terminal-Style Display

```tsx
<Video2AsciiZig
  src="/video.mp4"
  colored={false}        // Green terminal style
  numColumns={160}       // High density
  highlight={0}          // No background highlight
  brightness={1.0}
/>
```

### 2. Minimalist Art

```tsx
<Video2AsciiZig
  src="/video.mp4"
  charset="minimal"      // Only 4 characters
  colored={true}
  numColumns={60}        // Lower density
  highlight={30}         // Subtle background
/>
```

### 3. High-Detail Display

```tsx
<Video2AsciiZig
  src="/video.mp4"
  charset="detailed"     // 70 characters
  colored={true}
  numColumns={200}       // Very high density
  brightness={1.1}       // Slightly brighter
/>
```

### 4. Interactive Art Installation

```tsx
<Video2AsciiZig
  src="/video.mp4"
  enableMouse={true}
  trailLength={24}
  enableRipple={true}
  rippleSpeed={60}
  audioEffect={80}
  audioRange={70}
  showStats={true}
  className="w-full h-screen"
/>
```

### 5. Subtle Background Effect

```tsx
<Video2AsciiZig
  src="/video.mp4"
  charset="dots"
  blend={20}            // 20% blend with video
  numColumns={100}
  colored={false}
  brightness={0.8}
  enableMouse={false}
/>
```

## Troubleshooting

### "WASM module failed to load"

**Problem:** The component shows a loading spinner indefinitely.

**Solutions:**
1. Ensure the WASM file is being served with the correct MIME type:
   ```nginx
   location ~* \.wasm$ {
     default_type application/wasm;
   }
   ```
2. Check that the WASM file path is correct:
   ```tsx
   // For development, serve from public folder
   <Video2AsciiZig src="/video.mp4" wasmPath="/pixel-to-ascii-wasm.wasm" />
   ```
3. Check browser console for CORS errors.

### "WebGPU is not supported"

**Problem:** Component shows error about WebGPU not being available.

**Solutions:**
1. Update your browser to the latest version
2. Enable WebGPU in Firefox:
   - Go to `about:config`
   - Set `dom.webgpu.enabled` to `true`
3. Check if WebGPU is available:
   ```javascript
   if (!navigator.gpu) {
     console.error('WebGPU not supported');
   }
   ```

### Poor Performance

**Problem:** Frame rate drops below 30 FPS.

**Solutions:**
1. Reduce the number of columns:
   ```tsx
   <Video2AsciiZig numColumns={60} />  // Try lower values
   ```
2. Disable effects you don't need:
   ```tsx
   <Video2AsciiZig
     enableMouse={false}
     enableRipple={false}
     audioEffect={0}
   />
   ```
3. Use a simpler character set:
   ```tsx
   <Video2AsciiZig charset="minimal" />
   ```
4. Check hardware acceleration is enabled in your browser.

### Effects Not Working

**Problem:** Mouse glow or ripples don't appear.

**Solutions:**
1. Ensure effects are enabled:
   ```tsx
   <Video2AsciiZig
     enableMouse={true}    // Must be true for mouse glow
     enableRipple={true}   // Must be true for ripples
   />
   ```
2. Check browser console for JavaScript errors
3. Verify the video is playing (effects only work while video renders)

### Build Errors

**Problem:** `npm run build` fails.

**Solutions:**
1. Verify Zig version:
   ```bash
   zig version  # Should be 0.12.0 or later
   ```
2. Clear build cache:
   ```bash
   rm -rf zig-cache zig-out
   npm install
   npm run build
   ```
3. Update dependencies:
   ```bash
   npm install
   ```

## Next Steps

### Learn More

- **[Full API Reference](docs/API.md)** - Complete documentation of all props and methods
- **[Architecture Guide](ARCHITECTURE.md)** - Deep dive into the Zig/WebGPU implementation
- **[Performance Guide](docs/PERFORMANCE.md)** - Optimization tips and benchmarks

### Examples

Check out the [examples/](examples/) directory for more usage examples:
- `basic/` - Minimal working example
- `interactive/` - Full interactive demo
- `gallery/` - Character set showcase
- `installation/` - Art installation example

### Demo

Try the live demo: https://yourusername.github.io/pixel-to-ascii-zig

## Support

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Documentation**: [Full docs](docs/)

## Tips for Best Results

1. **Start with defaults**, then adjust one setting at a time
2. **Use higher column counts** for detailed videos, lower for abstract art
3. **Enable colored mode** for vibrant videos, disable for terminal aesthetic
4. **Add subtle blend** (10-20%) for a "video + ASCII" hybrid look
5. **Use audio reactivity** for music videos with strong beat
6. **Match character set** to your content (blocks for tech, dots for abstract)
7. **Keep trail length** between 16-24 for smooth mouse glow
8. **Monitor stats** during development to identify bottlenecks

## Performance Tips

- **Best Performance:**
  ```tsx
  <Video2AsciiZig
    numColumns={80}
    charset="minimal"
    enableMouse={false}
    colored={false}
  />
  ```

- **Best Quality:**
  ```tsx
  <Video2AsciiZig
    numColumns={160}
    charset="detailed"
    colored={true}
    highlight={20}
  />
  ```

- **Best for Art:**
  ```tsx
  <Video2AsciiZig
    numColumns={100}
    charset="blocks"
    blend={15}
    enableMouse={true}
    trailLength={24}
  />
  ```

---

**Ready to create stunning ASCII art?** 🎨

Start with the basic example, then explore the configuration options to find your perfect style. The Zig/WebGPU implementation gives you 60+ FPS performance even at high resolutions - so don't be afraid to experiment!