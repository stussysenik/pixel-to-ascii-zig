import SwiftUI
import PixelToAsciiEngine

/// SwiftUI view that renders ASCII art from the Zig engine using Canvas.
/// Reads from the engine's output buffer on each display link tick.
public struct AsciiRendererView: View {
    let engine: AsciiEngine
    let charset: String

    @State private var displayLink: DisplayLinkTimer?

    public init(engine: AsciiEngine, charset: String = AsciiEngine.charset) {
        self.engine = engine
        self.charset = charset
    }

    public var body: some View {
        Canvas { context, size in
            guard engine.isInitialized else { return }
            guard let buffer = engine.render() else { return }

            let cols = Int(engine.cols)
            let rows = Int(engine.rows)
            let charArray = Array(charset)
            let charCount = charArray.count

            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)
            let fontSize = min(cellW / 0.6, cellH)

            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = (row * cols + col) * 4
                    guard idx + 3 < buffer.count else { continue }

                    let charIdx = Int(buffer[idx])
                    let r = Double(buffer[idx + 1]) / 255.0
                    let g = Double(buffer[idx + 2]) / 255.0
                    let b = Double(buffer[idx + 3]) / 255.0

                    let safeCharIdx = min(charIdx, charCount - 1)
                    let ch = String(charArray[safeCharIdx])

                    let x = CGFloat(col) * cellW
                    let y = CGFloat(row) * cellH

                    var text = Text(ch)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundColor(Color(red: r, green: g, blue: b))

                    context.draw(text, at: CGPoint(x: x + cellW / 2, y: y + cellH / 2))
                }
            }
        }
        .background(.black)
        .onAppear { startDisplayLink() }
        .onDisappear { stopDisplayLink() }
    }

    private func startDisplayLink() {
        displayLink = DisplayLinkTimer { }
    }

    private func stopDisplayLink() {
        displayLink = nil
    }
}

/// Simple display-link-based timer for driving render updates.
final class DisplayLinkTimer {
    private var timer: Timer?
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
        // ~60fps fallback timer (CADisplayLink isn't directly available in SwiftUI)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            callback()
        }
    }

    deinit {
        timer?.invalidate()
    }
}
