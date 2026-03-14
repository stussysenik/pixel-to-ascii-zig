import Foundation
import CPixelToAscii

/// Swift wrapper around the Zig-compiled pixel-to-ascii C API.
/// Manages lifecycle and provides type-safe access to the renderer.
public final class AsciiEngine {
    public private(set) var cols: UInt32 = 0
    public private(set) var rows: UInt32 = 0
    public private(set) var isInitialized = false

    /// Standard ASCII character set (matches Zig's Charset.standard)
    public static let charset = " .:-=+*#%@"

    public init() {}

    deinit {
        cleanup()
    }

    /// Initialize the renderer with video dimensions and grid configuration.
    @discardableResult
    public func initialize(width: UInt32, height: UInt32, columns: UInt32, fontSize: Float = 10.0) -> Bool {
        let ok = pta_init(width, height, columns, fontSize)
        if ok {
            cols = pta_get_grid_cols()
            rows = pta_get_grid_rows()
            isInitialized = true
        }
        return ok
    }

    /// Upload a new RGBA video frame.
    @discardableResult
    public func updateFrame(data: UnsafePointer<UInt8>, width: UInt32, height: UInt32, stride: UInt32) -> Bool {
        guard isInitialized else { return false }
        return pta_update_video_frame(data, width, height, stride)
    }

    /// Render the current frame. Returns raw buffer pointer: [charIdx, r, g, b] per cell.
    public func render() -> UnsafeBufferPointer<UInt8>? {
        guard isInitialized else { return nil }
        guard let ptr = pta_render() else { return nil }
        let count = Int(cols) * Int(rows) * 4
        return UnsafeBufferPointer(start: ptr, count: count)
    }

    /// Set rendering options.
    public func setOptions(colored: Bool, blend: Float, highlight: Float, brightness: Float) {
        guard isInitialized else { return }
        pta_set_options(colored, blend, highlight, brightness)
    }

    /// Update mouse position for glow effect (normalized 0-1, -1 to disable).
    public func updateMouse(x: Float, y: Float) {
        guard isInitialized else { return }
        pta_update_mouse(x, y)
    }

    /// Add a click ripple effect at normalized position.
    public func addRipple(x: Float, y: Float) {
        guard isInitialized else { return }
        pta_add_ripple(x, y)
    }

    /// Clean up and free all resources.
    public func cleanup() {
        guard isInitialized else { return }
        pta_cleanup()
        isInitialized = false
        cols = 0
        rows = 0
    }
}
