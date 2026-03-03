import Foundation
import AppKit
import Observation
import ScreenshotGenCore

@Observable
@MainActor
final class ProjectState {
    var config: GeneratorConfig?
    var projectDir: URL?
    var selectedSlotIndex: Int?
    var logOutput: String = ""
    var isGenerating = false
    var errorMessage: String?
    var previewDeviceId: String?

    private let projectDirKey = "ScreenshotGenUI.projectDir"

    init() {
        if let saved = UserDefaults.standard.string(forKey: projectDirKey) {
            self.projectDir = URL(fileURLWithPath: saved)
        }
    }

    // MARK: - Derived paths

    var configURL: URL? {
        projectDir?.appendingPathComponent("config.json")
    }

    var rawDir: URL? {
        projectDir?.appendingPathComponent("RawScreenshots")
    }

    var outputDir: URL? {
        projectDir?.appendingPathComponent("Output")
    }

    var previewSpec: DeviceSpec? {
        if let id = previewDeviceId, let spec = DeviceSpec.from(id) {
            return spec
        }
        // Fall back to first selected device
        return config?.devices.compactMap({ DeviceSpec.from($0) }).first
    }

    // MARK: - Load / Save

    func loadIfNeeded() {
        guard let dir = projectDir else { return }
        loadConfig(fromDir: dir)
    }

    func loadConfig(fromDir dir: URL) {
        let url = dir.appendingPathComponent("config.json")
        do {
            config = try ScreenshotGenCore.loadConfig(from: url)
            projectDir = dir
            UserDefaults.standard.set(dir.path, forKey: projectDirKey)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load config.json: \(error.localizedDescription)"
            config = nil
        }
    }

    func saveConfig() {
        guard let config, let url = configURL else { return }
        do {
            try ScreenshotGenCore.saveConfig(config, to: url)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save config.json: \(error.localizedDescription)"
        }
    }

    // MARK: - Slot helpers

    func rawImageURL(for entry: ScreenshotEntry) -> URL? {
        rawDir?.appendingPathComponent(entry.rawImage)
    }

    func rawImageExists(for entry: ScreenshotEntry) -> Bool {
        guard let url = rawImageURL(for: entry) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func thumbnail(for entry: ScreenshotEntry) -> NSImage? {
        guard let url = rawImageURL(for: entry),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    // MARK: - Add / Remove Slots

    func addSlot() {
        guard config != nil else { return }
        let nextNumber = (config!.screenshots.count + 1)
        let id = String(format: "%02d", nextNumber)
        let entry = ScreenshotEntry(
            id: id,
            rawImage: "\(id)-screenshot.png",
            caption: "Your headline\ngoes here",
            supportText: "A subtitle explaining the feature"
        )
        config!.screenshots.append(entry)
        selectedSlotIndex = config!.screenshots.count - 1
    }

    func moveSlot(from source: IndexSet, to destination: Int) {
        guard config != nil else { return }
        config!.screenshots.move(fromOffsets: source, toOffset: destination)

        // Adjust selection to follow the moved item
        if let selected = selectedSlotIndex, let sourceIndex = source.first {
            if sourceIndex == selected {
                // The selected item was moved
                selectedSlotIndex = sourceIndex < destination ? destination - 1 : destination
            } else if sourceIndex < selected && destination > selected {
                selectedSlotIndex = selected - 1
            } else if sourceIndex > selected && destination <= selected {
                selectedSlotIndex = selected + 1
            }
        }
    }

    func removeSlot(at index: Int) {
        guard var screenshots = config?.screenshots,
              index >= 0, index < screenshots.count else { return }
        screenshots.remove(at: index)
        config?.screenshots = screenshots

        // Adjust selection
        if screenshots.isEmpty {
            selectedSlotIndex = nil
        } else if let selected = selectedSlotIndex, selected >= screenshots.count {
            selectedSlotIndex = screenshots.count - 1
        }
    }

    // MARK: - Import

    func importImages(from sourceURLs: [URL], assignments: [Int: URL]) {
        guard let rawDir else { return }
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
        } catch {
            errorMessage = "Could not create RawScreenshots/: \(error.localizedDescription)"
            return
        }

        guard let config else { return }

        for (slotIndex, sourceURL) in assignments {
            guard slotIndex < config.screenshots.count else { continue }
            let entry = config.screenshots[slotIndex]
            let destURL = rawDir.appendingPathComponent(entry.rawImage)

            do {
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: sourceURL, to: destURL)
            } catch {
                errorMessage = "Failed to copy \(sourceURL.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    func autoAssignByDate(images: [URL]) -> [Int: URL] {
        guard let config else { return [:] }
        let fm = FileManager.default

        // Sort by creation date, oldest first
        let sorted = images.sorted { a, b in
            let dateA = (try? fm.attributesOfItem(atPath: a.path)[.creationDate] as? Date) ?? Date.distantPast
            let dateB = (try? fm.attributesOfItem(atPath: b.path)[.creationDate] as? Date) ?? Date.distantPast
            return dateA < dateB
        }

        var assignments: [Int: URL] = [:]
        for (index, url) in sorted.enumerated() {
            guard index < config.screenshots.count else { break }
            assignments[index] = url
        }
        return assignments
    }

    // MARK: - Generate

    func runGenerate() {
        guard let projectDir, let config else { return }

        // Ask user where to save output
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose where to save generated screenshots"
        panel.prompt = "Save Here"

        // Default to the project's Output folder
        if let outputDir {
            panel.directoryURL = outputDir
        }

        guard panel.runModal() == .OK, let chosenDir = panel.url else { return }

        isGenerating = true
        logOutput = ""

        Task { @MainActor in
            do {
                _ = try generate(projectDir: projectDir, config: config, outputDir: chosenDir) { [weak self] line in
                    self?.logOutput += line + "\n"
                }
                NSWorkspace.shared.open(chosenDir)
            } catch {
                logOutput += "\n❌ \(error.localizedDescription)\n"
            }
            isGenerating = false
        }
    }

    // MARK: - Select project folder

    func selectProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the ScreenshotGen project folder (containing config.json)"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadConfig(fromDir: url)
    }
}
