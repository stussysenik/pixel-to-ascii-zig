// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PixelToAscii",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PixelToAsciiUI",
            targets: ["PixelToAsciiUI"]
        )
    ],
    targets: [
        // C library target — wraps the Zig-compiled static library
        .systemLibrary(
            name: "CPixelToAscii",
            path: "Sources/CPixelToAscii",
            pkgConfig: nil,
            providers: []
        ),
        // Swift engine — thin wrapper around C API
        .target(
            name: "PixelToAsciiEngine",
            dependencies: ["CPixelToAscii"],
            path: "Sources/PixelToAsciiEngine",
            linkerSettings: [
                .linkedLibrary("pixel-to-ascii", .when(platforms: [.macOS, .iOS])),
                .unsafeFlags(["-L", "../../zig-out/macos"], .when(platforms: [.macOS])),
                .unsafeFlags(["-L", "../../zig-out/ios"], .when(platforms: [.iOS])),
            ]
        ),
        // SwiftUI views
        .target(
            name: "PixelToAsciiUI",
            dependencies: ["PixelToAsciiEngine"],
            path: "Sources/PixelToAsciiUI"
        ),
    ]
)
