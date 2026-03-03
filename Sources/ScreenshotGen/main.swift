import Foundation
import AppKit
import ScreenshotGenCore

let packageDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // ScreenshotGen/
    .deletingLastPathComponent() // Sources/
    .deletingLastPathComponent() // ScreenshotGen (repo root)

// Support optional config path as first argument
let configPath: URL
if CommandLine.arguments.count > 1 {
    let arg = CommandLine.arguments[1]
    if arg.hasPrefix("/") {
        configPath = URL(fileURLWithPath: arg)
    } else {
        configPath = packageDir.appendingPathComponent(arg)
    }
} else {
    configPath = packageDir.appendingPathComponent("config.json")
}

// Load config
let config: GeneratorConfig
do {
    config = try loadConfig(from: configPath)
} catch {
    print("❌ Failed to load config at \(configPath.path): \(error.localizedDescription)")
    print("   Create a config.json file (see config.example.json for reference)")
    exit(1)
}

print("Config: \(configPath.lastPathComponent)")

Task { @MainActor in
    do {
        let result = try generate(projectDir: packageDir, config: config, logger: { print($0) })
        exit(result.skipped > 0 && result.generated == 0 ? 1 : 0)
    } catch {
        print("❌ \(error.localizedDescription)")
        exit(1)
    }
}

dispatchMain()
