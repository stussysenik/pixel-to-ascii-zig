import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO
import PixelToAsciiEngine
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

/// Main SwiftUI console for loading visual assets and rendering them as ASCII.
public struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var isDropTargeted = false

    public init() {}

    public var body: some View {
        ZStack {
            backgroundLayer

            Group {
                if viewModel.hasAsset {
                    liveConsole
                } else {
                    dropPrompt
                }
            }
            .padding(24)
        }
        .frame(minWidth: 960, minHeight: 680)
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.image, .movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.loadAsset(url: url)
            }
        }
        .onDrop(of: [.fileURL, .image, .movie, .video], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.08),
                    Color(red: 0.02, green: 0.03, blue: 0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geometry in
                Path { path in
                    let spacing: CGFloat = 32
                    stride(from: 0.0, through: geometry.size.width, by: spacing).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }

                    stride(from: 0.0, through: geometry.size.height, by: spacing).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }

    private var liveConsole: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                )

            AsciiRendererView(engine: viewModel.engine)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(26)

            VStack(spacing: 0) {
                consoleHeader
                Spacer()
                consoleFooter
            }
            .padding(22)
        }
    }

    private var consoleHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ASCII VISUAL CONSOLE")
                    .font(.system(size: 34, weight: .black, design: .default))
                    .foregroundStyle(.white)

                Text(viewModel.signalLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.84, blue: 0.58))
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 10) {
                chip(viewModel.assetMode.uppercased(), tint: Color.orange)
                chip(viewModel.assetResolution, tint: Color.yellow)
                chip("\(viewModel.engine.cols)x\(viewModel.engine.rows)", tint: Color.green)
            }
        }
    }

    private var consoleFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.assetName)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Drop another visual asset or reload from disk to swap the raster feed.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 16)

            Button(viewModel.isPaused ? "Resume" : "Pause") {
                viewModel.togglePlayback()
            }
            .buttonStyle(ConsoleButtonStyle(primary: true))
            .disabled(!viewModel.canTogglePlayback)

            Button("Choose Asset") {
                viewModel.showFilePicker = true
            }
            .buttonStyle(ConsoleButtonStyle(primary: false))
        }
        .padding(16)
        .background(.black.opacity(0.64))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dropPrompt: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("SYSTEM ROLE // STAFF EXPERIENCE DESIGN ENGINEER")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Color.orange.opacity(0.86))

            Text("Deploy a visual asset into the Swift console")
                .font(.system(size: 58, weight: .black, design: .default))
                .foregroundStyle(.white)
                .lineSpacing(-6)

            Text(
                "Images and video are sampled into Zig, translated into ASCII cells, and rendered inside a live console frame."
            )
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: 620, alignment: .leading)

            HStack(spacing: 12) {
                Button("Choose Asset") {
                    viewModel.showFilePicker = true
                }
                .buttonStyle(ConsoleButtonStyle(primary: true))

                Text(isDropTargeted ? "Release to ingest" : "Drag image or video from Finder")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDropTargeted ? Color.green : .white.opacity(0.66))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Accepted formats")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.yellow.opacity(0.8))

                Text("PNG · JPG · WEBP · GIF · MP4 · MOV · M4V")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(36)
        .frame(maxWidth: 820, alignment: .leading)
        .background(.black.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    isDropTargeted ? Color.green.opacity(0.55) : Color.orange.opacity(0.22),
                    lineWidth: 1.5)
        )
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.34), lineWidth: 1)
            )
    }
}

@MainActor
final class ContentViewModel: ObservableObject {
    enum AssetKind {
        case none
        case image
        case video
    }

    let engine = AsciiEngine()

    @Published var hasAsset = false
    @Published var isPaused = false
    @Published var showFilePicker = false
    @Published var assetName = "Awaiting ingest"
    @Published var assetResolution = "-- x --"
    @Published var assetMode = "Idle"
    @Published var signalLabel = "Drop a still or motion asset to begin."

    var canTogglePlayback: Bool {
        assetKind == .video
    }

    private var assetKind: AssetKind = .none
    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var frameTimer: Timer?
    private var playbackObserver: NSObjectProtocol?
    private var rgbaBuffer: [UInt8] = []

    func loadAsset(url: URL) {
        Task {
            await loadAssetTask(url: url)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                item, _ in
                guard let url = Self.droppedURL(from: item) else { return }
                Task { @MainActor in
                    self.loadAsset(url: url)
                }
            }
            return true
        }

        return false
    }

    func togglePlayback() {
        guard assetKind == .video, let player else { return }

        if isPaused {
            player.play()
            signalLabel = "Motion feed resumed."
            assetMode = "Video live"
        } else {
            player.pause()
            pullVideoFrame()
            signalLabel = "Motion feed paused on current frame."
            assetMode = "Video paused"
        }

        isPaused.toggle()
    }

    private func loadAssetTask(url: URL) async {
        resetPipeline(clearMetadata: true)
        signalLabel = "Ingesting \(url.lastPathComponent)…"

        if Self.isImageURL(url) {
            loadImage(url: url)
        } else {
            await loadVideo(url: url)
        }
    }

    private func loadImage(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            signalLabel = "Unable to decode image asset."
            return
        }

        let width = UInt32(image.width)
        let height = UInt32(image.height)

        guard engine.initialize(width: width, height: height, columns: 80, fontSize: 10) else {
            signalLabel = "Failed to initialize Zig renderer."
            return
        }

        updateEngine(with: image)
        _ = engine.render()

        assetKind = .image
        hasAsset = true
        isPaused = true
        assetName = url.lastPathComponent
        assetResolution = "\(image.width) x \(image.height)"
        assetMode = "Still frame"
        signalLabel = "Still asset resolved into ASCII raster."
    }

    private func loadVideo(url: URL) async {
        let asset = AVAsset(url: url)

        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                signalLabel = "No video track found."
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let width = UInt32(abs(Int(naturalSize.width.rounded())))
            let height = UInt32(abs(Int(naturalSize.height.rounded())))

            guard width > 0, height > 0 else {
                signalLabel = "Video has invalid dimensions."
                return
            }

            guard engine.initialize(width: width, height: height, columns: 80, fontSize: 10) else {
                signalLabel = "Failed to initialize Zig renderer."
                return
            }

            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ])

            let item = AVPlayerItem(asset: asset)
            item.add(output)

            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .none

            self.videoOutput = output
            self.player = player
            attachPlaybackObserver(to: item, player: player)
            startFrameTimer()
            player.play()

            assetKind = .video
            hasAsset = true
            isPaused = false
            assetName = url.lastPathComponent
            assetResolution = "\(width) x \(height)"
            assetMode = "Video live"
            signalLabel = "Video feed translating through Zig."
        } catch {
            signalLabel = "Unable to prepare video asset."
        }
    }

    private func startFrameTimer() {
        frameTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.pullVideoFrame()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func attachPlaybackObserver(to item: AVPlayerItem, player: AVPlayer) {
        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
        }

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func pullVideoFrame() {
        guard assetKind == .video,
            let videoOutput
        else { return }

        let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
            let pixelBuffer = videoOutput.copyPixelBuffer(
                forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }

        updateEngine(with: pixelBuffer)
    }

    private func updateEngine(with image: CGImage) {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4

        rgbaBuffer = [UInt8](repeating: 0, count: bytesPerRow * height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo =
            CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        rgbaBuffer.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                )
            else { return }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        rgbaBuffer.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = engine.updateFrame(
                data: baseAddress,
                width: UInt32(width),
                height: UInt32(height),
                stride: UInt32(bytesPerRow)
            )
        }
    }

    private func updateEngine(with pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let destinationBytesPerRow = width * 4

        if rgbaBuffer.count != destinationBytesPerRow * height {
            rgbaBuffer = [UInt8](repeating: 0, count: destinationBytesPerRow * height)
        }

        let source = baseAddress.assumingMemoryBound(to: UInt8.self)
        rgbaBuffer.withUnsafeMutableBufferPointer { destination in
            guard let destinationBase = destination.baseAddress else { return }

            for row in 0..<height {
                let sourceRow = source.advanced(by: row * sourceBytesPerRow)
                let destinationRow = destinationBase.advanced(by: row * destinationBytesPerRow)

                for column in 0..<width {
                    let sourceIndex = column * 4
                    let destinationIndex = column * 4

                    let blue = sourceRow[sourceIndex]
                    let green = sourceRow[sourceIndex + 1]
                    let red = sourceRow[sourceIndex + 2]
                    let alpha = sourceRow[sourceIndex + 3]

                    destinationRow[destinationIndex] = red
                    destinationRow[destinationIndex + 1] = green
                    destinationRow[destinationIndex + 2] = blue
                    destinationRow[destinationIndex + 3] = alpha
                }
            }
        }

        rgbaBuffer.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = engine.updateFrame(
                data: baseAddress,
                width: UInt32(width),
                height: UInt32(height),
                stride: UInt32(destinationBytesPerRow)
            )
        }
    }

    private func resetPipeline(clearMetadata: Bool) {
        frameTimer?.invalidate()
        frameTimer = nil

        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
            self.playbackObserver = nil
        }

        player?.pause()
        player = nil
        videoOutput = nil
        rgbaBuffer.removeAll(keepingCapacity: true)

        if engine.isInitialized {
            engine.cleanup()
        }

        hasAsset = false
        isPaused = false
        assetKind = .none

        if clearMetadata {
            assetName = "Awaiting ingest"
            assetResolution = "-- x --"
            assetMode = "Idle"
            signalLabel = "Drop a still or motion asset to begin."
        }
    }

    nonisolated private static func isImageURL(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    nonisolated private static func droppedURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

private struct ConsoleButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .tracking(1.5)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(primary ? Color.orange : Color.white.opacity(0.08))
            .foregroundStyle(primary ? Color.black : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(primary ? 0.0 : 0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}
