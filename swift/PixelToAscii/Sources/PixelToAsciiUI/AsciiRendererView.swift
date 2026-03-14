import PixelToAsciiEngine
import SwiftUI

/// SwiftUI renderer that paints the engine output as live ASCII glyphs.
public struct AsciiRendererView: View {
    let engine: AsciiEngine
    let charset: [Character]

    public init(engine: AsciiEngine, charset: String = AsciiEngine.charset) {
        self.engine = engine
        self.charset = Array(charset)
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas(opaque: true, colorMode: .linear) { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.03, green: 0.04, blue: 0.05))
                )

                guard engine.isInitialized else { return }
                guard let buffer = engine.render() else { return }

                let cols = Int(engine.cols)
                let rows = Int(engine.rows)
                guard cols > 0, rows > 0, !charset.isEmpty else { return }

                let cellWidth = size.width / CGFloat(cols)
                let cellHeight = size.height / CGFloat(rows)
                let fontSize = min(cellWidth / 0.58, cellHeight)

                for row in 0..<rows {
                    for col in 0..<cols {
                        let index = (row * cols + col) * 4
                        guard index + 3 < buffer.count else { continue }

                        let glyphIndex = min(Int(buffer[index]), charset.count - 1)
                        let red = Double(buffer[index + 1]) / 255.0
                        let green = Double(buffer[index + 2]) / 255.0
                        let blue = Double(buffer[index + 3]) / 255.0

                        if glyphIndex == 0, red == 0, green == 0, blue == 0 {
                            continue
                        }

                        let glyph = String(charset[glyphIndex])
                        let point = CGPoint(
                            x: CGFloat(col) * cellWidth + cellWidth / 2,
                            y: CGFloat(row) * cellHeight + cellHeight / 2
                        )

                        let text = Text(glyph)
                            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: red, green: green, blue: blue))

                        context.draw(text, at: point)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color.black,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
