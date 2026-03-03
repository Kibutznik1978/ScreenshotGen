import Foundation
import AppKit
import Observation
import ScreenshotGenCore

@Observable
@MainActor
final class ProjectStore {
    var projects: [Project] = []
    var selectedProjectId: UUID?
    var selectedSlotIndex: Int?
    var logOutput: String = ""
    var isGenerating = false
    var errorMessage: String?
    var previewDeviceId: String?

    private var saveTask: Task<Void, Never>?
    private let selectedProjectKey = "ScreenshotGenUI.selectedProjectId"

    // MARK: - Computed Properties

    var selectedProject: Project? {
        get {
            guard let id = selectedProjectId else { return nil }
            return projects.first { $0.id == id }
        }
        set {
            guard let newValue, let index = projects.firstIndex(where: { $0.id == newValue.id }) else { return }
            projects[index] = newValue
        }
    }

    var config: GeneratorConfig? {
        get { selectedProject?.config }
        set {
            guard let newValue, let id = selectedProjectId,
                  let index = projects.firstIndex(where: { $0.id == id }) else { return }
            projects[index].config = newValue
        }
    }

    var projectDir: URL? {
        guard let id = selectedProjectId else { return nil }
        return projectsBaseDir.appendingPathComponent(id.uuidString)
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
        return config?.devices.compactMap({ DeviceSpec.from($0) }).first
    }

    // MARK: - Base Directory

    private var projectsBaseDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ScreenshotGen/projects")
    }

    // MARK: - Init

    init() {
        let fm = FileManager.default
        try? fm.createDirectory(at: projectsBaseDir, withIntermediateDirectories: true)

        loadAllProjects()

        if projects.isEmpty {
            let defaultProj = Project.defaultProject()
            projects.append(defaultProj)
            save(defaultProj)
        }

        // Restore selection
        if let savedId = UserDefaults.standard.string(forKey: selectedProjectKey),
           let uuid = UUID(uuidString: savedId),
           projects.contains(where: { $0.id == uuid }) {
            selectedProjectId = uuid
        } else {
            selectedProjectId = projects.first?.id
        }
    }

    // MARK: - CRUD

    func createProject(name: String = "New Project") {
        let project = Project(
            id: UUID(),
            name: name,
            createdAt: Date(),
            config: GeneratorConfig(
                gradientTopColor: "#337AF5",
                gradientBottomColor: "#245CCC",
                textColor: "#FFFFFF",
                supportTextOpacity: 0.8,
                devices: [
                    "iphone-1290x2796",
                    "iphone-1284x2778",
                    "iphone-1179x2556",
                    "iphone-1170x2532"
                ],
                screenshots: [
                    ScreenshotEntry(id: "01", rawImage: "01-screenshot.png",
                                    caption: "Your headline\ngoes here",
                                    supportText: "A subtitle explaining the feature"),
                ]
            )
        )
        projects.append(project)
        save(project)
        selectedProjectId = project.id
    }

    func deleteProject(_ id: UUID) {
        guard projects.count > 1 else { return }
        let fm = FileManager.default
        let dir = projectsBaseDir.appendingPathComponent(id.uuidString)
        try? fm.removeItem(at: dir)
        projects.removeAll { $0.id == id }

        if selectedProjectId == id {
            selectedProjectId = projects.first?.id
        }
    }

    func renameProject(_ id: UUID, to newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName
        save(projects[index])
    }

    // MARK: - Persistence

    func loadAllProjects() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: projectsBaseDir,
                                                          includingPropertiesForKeys: nil) else { return }

        var loaded: [Project] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for dir in contents where dir.hasDirectoryPath {
            let jsonURL = dir.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let project = try? decoder.decode(Project.self, from: data) else { continue }
            loaded.append(project)
        }

        projects = loaded.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ project: Project) {
        let fm = FileManager.default
        let dir = projectsBaseDir.appendingPathComponent(project.id.uuidString)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let rawScreenshotsDir = dir.appendingPathComponent("RawScreenshots")
        try? fm.createDirectory(at: rawScreenshotsDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(project)
            let jsonURL = dir.appendingPathComponent("project.json")
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            errorMessage = "Failed to save project: \(error.localizedDescription)"
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let project = selectedProject {
                save(project)
            }
        }
    }

    func persistSelection() {
        if let id = selectedProjectId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedProjectKey)
        }
    }

    // MARK: - Raw Image Helpers

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

    // MARK: - Image Import

    func importImage(from sourceURL: URL, toSlotIndex index: Int) {
        guard let rawDir, let config,
              index >= 0, index < config.screenshots.count else { return }
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
        } catch {
            errorMessage = "Could not create RawScreenshots/: \(error.localizedDescription)"
            return
        }

        let entry = config.screenshots[index]
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

    // MARK: - Slot Operations

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
        scheduleSave()
    }

    func moveSlot(from source: IndexSet, to destination: Int) {
        guard config != nil else { return }
        config!.screenshots.move(fromOffsets: source, toOffset: destination)

        if let selected = selectedSlotIndex, let sourceIndex = source.first {
            if sourceIndex == selected {
                selectedSlotIndex = sourceIndex < destination ? destination - 1 : destination
            } else if sourceIndex < selected && destination > selected {
                selectedSlotIndex = selected - 1
            } else if sourceIndex > selected && destination <= selected {
                selectedSlotIndex = selected + 1
            }
        }
        scheduleSave()
    }

    func removeSlot(at index: Int) {
        guard var screenshots = config?.screenshots,
              index >= 0, index < screenshots.count else { return }
        screenshots.remove(at: index)
        config?.screenshots = screenshots

        if screenshots.isEmpty {
            selectedSlotIndex = nil
        } else if let selected = selectedSlotIndex, selected >= screenshots.count {
            selectedSlotIndex = screenshots.count - 1
        }
        scheduleSave()
    }

    // MARK: - Auto-Assign

    func autoAssignByDate(images: [URL]) -> [Int: URL] {
        guard let config else { return [:] }
        let fm = FileManager.default

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

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose where to save generated screenshots"
        panel.prompt = "Save Here"

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
}
