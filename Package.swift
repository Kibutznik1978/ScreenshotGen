// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ScreenshotGen",
    platforms: [.macOS(.v14)],
    targets: [
        // Shared library with models, views, and export logic
        .target(
            name: "ScreenshotGenCore",
            path: "Sources/ScreenshotGenCore"
        ),

        // CLI tool (original behavior)
        .executableTarget(
            name: "ScreenshotGen",
            dependencies: ["ScreenshotGenCore"],
            path: "Sources/ScreenshotGenCLI"
        ),

        // macOS GUI app
        .executableTarget(
            name: "ScreenshotGenUI",
            dependencies: ["ScreenshotGenCore"],
            path: "Sources/ScreenshotGenUI"
        )
    ]
)
