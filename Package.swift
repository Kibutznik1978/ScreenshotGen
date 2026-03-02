// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ScreenshotGen",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenshotGen",
            path: "Sources"
        )
    ]
)
