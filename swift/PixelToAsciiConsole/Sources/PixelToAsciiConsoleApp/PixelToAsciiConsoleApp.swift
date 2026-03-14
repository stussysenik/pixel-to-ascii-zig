import PixelToAsciiUI
import SwiftUI

@main
struct PixelToAsciiConsoleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
    }
}
