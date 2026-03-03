import Foundation
import AppKit
import ScreenshotGenCore

let packageDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // ScreenshotGenCLI/
    .deletingLastPathComponent() // Sources/
    .deletingLastPathComponent() // ScreenshotGen/

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

let rawDir = packageDir.appendingPathComponent("RawScreenshots")
let outputDir = packageDir.appendingPathComponent("Output")

let fm = FileManager.default

// Load config
let config: GeneratorConfig
do {
    config = try loadConfig(from: configPath)
} catch {
    print("❌ Failed to load config at \(configPath.path): \(error.localizedDescription)")
    print("   Create a config.json file (see config.example.json for reference)")
    exit(1)
}

let devices = config.resolvedDevices
guard !devices.isEmpty else {
    print("❌ No valid devices in config. Use: \(DeviceSpec.allCases.map(\.rawValue).joined(separator: ", "))")
    exit(1)
}

guard !config.screenshots.isEmpty else {
    print("❌ No screenshots defined in config.")
    exit(1)
}

// Ensure directories exist
try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

for device in devices {
    let deviceDir = outputDir.appendingPathComponent(device.rawValue)
    try fm.createDirectory(at: deviceDir, withIntermediateDirectories: true)
}

print("ScreenshotGen")
print("Config: \(configPath.lastPathComponent)")
print("Devices: \(devices.map(\.label).joined(separator: ", "))")
print("Screenshots: \(config.screenshots.count)")
print("")

Task { @MainActor in
    var generated = 0
    var skipped = 0

    for entry in config.screenshots {
        let rawURL = rawDir.appendingPathComponent(entry.rawImage)

        guard fm.fileExists(atPath: rawURL.path) else {
            print("⏭  Skipping \(entry.id): \(entry.rawImage) not found in RawScreenshots/")
            skipped += 1
            continue
        }

        guard let screenshot = NSImage(contentsOf: rawURL) else {
            print("⚠️  Could not load image: \(entry.rawImage)")
            skipped += 1
            continue
        }

        for device in devices {
            let view = ScreenshotView(
                entry: entry,
                screenshot: screenshot,
                spec: device,
                config: config
            )

            let deviceDir = outputDir.appendingPathComponent(device.rawValue)
            let outputURL = deviceDir.appendingPathComponent("\(entry.id)-screenshot.png")

            do {
                try exportPNG(view: view, spec: device, to: outputURL)
                print("✅ \(device.rawValue)/\(entry.id)-screenshot.png")
                generated += 1
            } catch {
                print("❌ \(device.rawValue)/\(entry.id): \(error.localizedDescription)")
                skipped += 1
            }
        }
    }

    print("\nDone — \(generated) generated, \(skipped) skipped")
    if skipped > 0, generated == 0 {
        print("Drop raw simulator PNGs into RawScreenshots/ and re-run.")
    }

    exit(0)
}

dispatchMain()
