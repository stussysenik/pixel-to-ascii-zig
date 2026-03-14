#!/bin/bash
set -euo pipefail

# Build xcframework for macOS and iOS
# Produces: build/PixelToAscii.xcframework

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"

echo "==> Building macOS arm64 static library..."
cd "$ROOT_DIR"
zig build macos -Doptimize=ReleaseFast

echo "==> Building iOS arm64 static library..."
zig build ios -Doptimize=ReleaseFast

echo "==> Creating xcframework..."
mkdir -p "$BUILD_DIR"

# Create xcframework from the two static libraries
xcodebuild -create-xcframework \
  -library "zig-out/macos/libpixel-to-ascii.a" \
  -headers "include/" \
  -library "zig-out/ios/libpixel-to-ascii.a" \
  -headers "include/" \
  -output "$BUILD_DIR/PixelToAscii.xcframework"

echo "==> Done: $BUILD_DIR/PixelToAscii.xcframework"
