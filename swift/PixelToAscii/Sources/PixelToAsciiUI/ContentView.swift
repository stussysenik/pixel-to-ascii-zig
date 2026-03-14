import SwiftUI
import PixelToAsciiEngine
import AVFoundation
import UniformTypeIdentifiers

/// Main content view with file picker and ASCII renderer.
public struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isPlaying {
                AsciiRendererView(engine: viewModel.engine)
                    .overlay(alignment: .topLeading) {
                        statsOverlay
                    }
                    .overlay(alignment: .bottom) {
                        controlBar
                    }
            } else {
                dropPrompt
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var dropPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Drop a video file to start")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Choose File") {
                viewModel.showFilePicker = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.loadVideo(url: url)
            }
        }
        .onDrop(of: [.movie, .fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }

    private var statsOverlay: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.engine.cols)x\(viewModel.engine.rows)")
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.green)
        .padding(8)
        .background(.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(12)
    }

    private var controlBar: some View {
        HStack {
            Button(viewModel.isPaused ? "Play" : "Pause") {
                viewModel.togglePlayback()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(16)
    }
}

@MainActor
final class ContentViewModel: ObservableObject {
    let engine = AsciiEngine()
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var showFilePicker = false

    func loadVideo(url: URL) {
        // Video loading would use AVAssetReader to extract frames
        // This is the scaffold — actual frame extraction is platform-specific
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }

        let size = track.naturalSize
        let width = UInt32(size.width)
        let height = UInt32(size.height)

        engine.initialize(width: width, height: height, columns: 80, fontSize: 10)
        isPlaying = true
    }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    Task { @MainActor in
                        self.loadVideo(url: url)
                    }
                }
            }
        }
    }

    func togglePlayback() {
        isPaused.toggle()
    }
}
