import Foundation
import AppKit

/// Runs the screenshot generator for a given project directory and config.
/// - Parameters:
///   - projectDir: Root directory containing RawScreenshots/ and config.json
///   - config: The parsed generator configuration
///   - outputDir: Optional output directory. If nil, defaults to projectDir/Output
///   - logger: Closure called with log messages (e.g. print or UI text view append)
/// - Returns: Tuple of (generated count, skipped count)
@MainActor
public func generate(
    projectDir: URL,
    config: GeneratorConfig,
    outputDir: URL? = nil,
    logger: @escaping (String) -> Void
) throws -> (generated: Int, skipped: Int) {
    let rawDir = projectDir.appendingPathComponent("RawScreenshots")
    let outputDir = outputDir ?? projectDir.appendingPathComponent("Output")
    let fm = FileManager.default

    let devices = config.resolvedDevices
    guard !devices.isEmpty else {
        throw GeneratorError.noValidDevices
    }

    guard !config.screenshots.isEmpty else {
        throw GeneratorError.noScreenshots
    }

    // Ensure directories exist
    try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

    for device in devices {
        let deviceDir = outputDir.appendingPathComponent(device.id)
        try fm.createDirectory(at: deviceDir, withIntermediateDirectories: true)
    }

    logger("ScreenshotGen")
    logger("Devices: \(devices.map(\.label).joined(separator: ", "))")
    logger("Screenshots: \(config.screenshots.count)")
    logger("")

    var generated = 0
    var skipped = 0

    for entry in config.screenshots {
        let rawURL = rawDir.appendingPathComponent(entry.rawImage)

        guard fm.fileExists(atPath: rawURL.path) else {
            logger("⏭  Skipping \(entry.id): \(entry.rawImage) not found in RawScreenshots/")
            skipped += 1
            continue
        }

        guard let screenshot = NSImage(contentsOf: rawURL) else {
            logger("⚠️  Could not load image: \(entry.rawImage)")
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

            let deviceDir = outputDir.appendingPathComponent(device.id)
            let outputURL = deviceDir.appendingPathComponent("\(entry.id)-screenshot.png")

            do {
                try exportPNG(view: view, spec: device, to: outputURL)
                logger("✅ \(device.id)/\(entry.id)-screenshot.png")
                generated += 1
            } catch {
                logger("❌ \(device.id)/\(entry.id): \(error.localizedDescription)")
                skipped += 1
            }
        }
    }

    logger("")
    logger("Done — \(generated) generated, \(skipped) skipped")
    if skipped > 0, generated == 0 {
        logger("Drop raw simulator PNGs into RawScreenshots/ and re-run.")
    }

    return (generated, skipped)
}

public enum GeneratorError: LocalizedError {
    case noValidDevices
    case noScreenshots

    public var errorDescription: String? {
        switch self {
        case .noValidDevices:
            "No valid devices in config. Use: \(DeviceSpec.allSpecs.map(\.id).joined(separator: ", "))"
        case .noScreenshots:
            "No screenshots defined in config."
        }
    }
}
