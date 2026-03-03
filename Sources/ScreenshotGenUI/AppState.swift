import SwiftUI
import AppKit
import ScreenshotGenCore

@MainActor
@Observable
final class AppState {
    // MARK: - Config properties
    var gradientTopColor: Color = Color(hex: "#337AF5")
    var gradientBottomColor: Color = Color(hex: "#245CCC")
    var textColor: Color = .white
    var supportTextOpacity: Double = 0.8
    var enabledDevices: Set<DeviceSpec> = [.iPhone6_7, .iPad12_9]

    // MARK: - Screenshots
    var entries: [ScreenshotEntryModel] = []
    var selectedEntryID: String?

    // MARK: - Preview
    var previewDevice: DeviceSpec = .iPhone6_7

    // MARK: - Export state
    var isExporting = false
    var exportMessage = ""

    // MARK: - Project paths
    var projectDir: URL

    var rawDir: URL { projectDir.appendingPathComponent("RawScreenshots") }
    var outputDir: URL { projectDir.appendingPathComponent("Output") }
    var configURL: URL { projectDir.appendingPathComponent("config.json") }

    var selectedEntry: ScreenshotEntryModel? {
        get { entries.first { $0.id == selectedEntryID } }
        set {
            if let newValue, let idx = entries.firstIndex(where: { $0.id == newValue.id }) {
                entries[idx] = newValue
            }
        }
    }

    init(projectDir: URL? = nil) {
        // Default to the package directory (two levels up from this source file)
        self.projectDir = projectDir ?? {
            // Use a sensible default; can be overridden
            let bundlePath = Bundle.main.bundlePath
            return URL(fileURLWithPath: bundlePath)
                .deletingLastPathComponent()
        }()

        // Try to load existing config
        loadFromConfig()
    }

    // MARK: - Config I/O

    func loadFromConfig() {
        guard let config = try? ScreenshotGenCore.loadConfig(from: configURL) else { return }

        gradientTopColor = config.gradientTop
        gradientBottomColor = config.gradientBottom
        textColor = config.text
        supportTextOpacity = config.resolvedSupportTextOpacity
        enabledDevices = Set(config.resolvedDevices)

        entries = config.screenshots.map { entry in
            let imageURL = rawDir.appendingPathComponent(entry.rawImage)
            let image = NSImage(contentsOf: imageURL)
            return ScreenshotEntryModel(
                id: entry.id,
                rawImage: entry.rawImage,
                caption: entry.caption,
                supportText: entry.supportText,
                image: image
            )
        }

        selectedEntryID = entries.first?.id
    }

    func buildConfig() -> GeneratorConfig {
        GeneratorConfig(
            gradientTopColor: gradientTopColor.hexString,
            gradientBottomColor: gradientBottomColor.hexString,
            textColor: textColor.hexString,
            supportTextOpacity: supportTextOpacity,
            devices: enabledDevices.map(\.rawValue).sorted(),
            screenshots: entries.map { entry in
                ScreenshotEntry(
                    id: entry.id,
                    rawImage: entry.rawImage,
                    caption: entry.caption,
                    supportText: entry.supportText
                )
            }
        )
    }

    func saveConfigFile() {
        let config = buildConfig()
        try? ScreenshotGenCore.saveConfig(config, to: configURL)
    }

    // MARK: - Screenshot management

    func addEntry() {
        let nextID = String(format: "%02d", entries.count + 1)
        let entry = ScreenshotEntryModel(
            id: nextID,
            rawImage: "\(nextID)-screenshot.png",
            caption: "Your headline\ngoes here",
            supportText: "A subtitle explaining the feature"
        )
        entries.append(entry)
        selectedEntryID = entry.id
    }

    func removeEntry(_ id: String) {
        entries.removeAll { $0.id == id }
        if selectedEntryID == id {
            selectedEntryID = entries.first?.id
        }
    }

    func moveEntries(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        // Re-number IDs to keep them sequential
        for (index, _) in entries.enumerated() {
            entries[index].id = String(format: "%02d", index + 1)
        }
    }

    func pickImage(for entryID: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a screenshot image"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }

        // Copy to RawScreenshots if not already there
        let fm = FileManager.default
        try? fm.createDirectory(at: rawDir, withIntermediateDirectories: true)

        let destFilename = url.lastPathComponent
        let destURL = rawDir.appendingPathComponent(destFilename)

        if !fm.fileExists(atPath: destURL.path) {
            try? fm.copyItem(at: url, to: destURL)
        }

        entries[idx].rawImage = destFilename
        entries[idx].image = NSImage(contentsOf: destURL)
    }

    // MARK: - Export

    func exportAll() {
        isExporting = true
        exportMessage = ""

        let config = buildConfig()
        let devices = Array(enabledDevices)
        let fm = FileManager.default

        var generated = 0
        var skipped = 0

        // Ensure output dirs
        try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
        for device in devices {
            let deviceDir = outputDir.appendingPathComponent(device.rawValue)
            try? fm.createDirectory(at: deviceDir, withIntermediateDirectories: true)
        }

        for entry in entries {
            guard let image = entry.image else {
                skipped += 1
                continue
            }

            let screenshotEntry = ScreenshotEntry(
                id: entry.id,
                rawImage: entry.rawImage,
                caption: entry.caption,
                supportText: entry.supportText
            )

            for device in devices {
                let view = ScreenshotView(
                    entry: screenshotEntry,
                    screenshot: image,
                    spec: device,
                    config: config
                )

                let deviceDir = outputDir.appendingPathComponent(device.rawValue)
                let outputURL = deviceDir.appendingPathComponent("\(entry.id)-screenshot.png")

                do {
                    try exportPNG(view: view, spec: device, to: outputURL)
                    generated += 1
                } catch {
                    skipped += 1
                }
            }
        }

        exportMessage = "\(generated) generated, \(skipped) skipped"
        isExporting = false
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose ScreenshotGen project folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        projectDir = url
        loadFromConfig()
    }
}

// MARK: - Entry Model (mutable, for the UI)

struct ScreenshotEntryModel: Identifiable, Hashable {
    var id: String
    var rawImage: String
    var caption: String
    var supportText: String
    var image: NSImage?

    static func == (lhs: ScreenshotEntryModel, rhs: ScreenshotEntryModel) -> Bool {
        lhs.id == rhs.id
            && lhs.rawImage == rhs.rawImage
            && lhs.caption == rhs.caption
            && lhs.supportText == rhs.supportText
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
