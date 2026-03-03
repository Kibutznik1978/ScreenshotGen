// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ScreenshotGen",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ScreenshotGenCore", targets: ["ScreenshotGenCore"]),
    ],
    targets: [
        .target(
            name: "ScreenshotGenCore",
            path: "Sources/ScreenshotGenCore"
        ),
        .executableTarget(
            name: "ScreenshotGen",
            dependencies: ["ScreenshotGenCore"],
            path: "Sources/ScreenshotGen"
        ),
        .executableTarget(
            name: "ScreenshotGenUI",
            dependencies: ["ScreenshotGenCore"],
            path: "Sources/ScreenshotGenUI",
            exclude: ["Info.plist", "ScreenshotGenUI.entitlements", "Assets.xcassets"]
        ),
    ]
)
