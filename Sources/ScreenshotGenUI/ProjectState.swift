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
        isGenerating = true
        logOutput = ""

        Task { @MainActor in
            do {
                _ = try generate(projectDir: projectDir, config: config) { [weak self] line in
                    self?.logOutput += line + "\n"
                }
                // Open output folder
                if let outputDir {
                    NSWorkspace.shared.open(outputDir)
                }
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
