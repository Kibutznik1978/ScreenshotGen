# Folder-Free App UX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the project-folder-based UX with an Application Support-backed multi-project app that opens ready to use with no folder selection.

**Architecture:** Projects stored in `~/Library/Application Support/ScreenshotGen/projects/<uuid>/`. Each project has a `project.json` (metadata + GeneratorConfig) and `RawScreenshots/` folder (images). `ProjectStore` replaces `ProjectState` for all persistence. UI adds a project sidebar. `ScreenshotGenCore` stays untouched.

**Tech Stack:** Swift 5.10, SwiftUI, macOS 14+, `@Observable`, ScreenshotGenCore library

---

### Task 1: Create Project Model

**Files:**
- Create: `Sources/ScreenshotGenUI/Project.swift`

**Step 1: Create the Project struct**

```swift
import Foundation
import ScreenshotGenCore

struct Project: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var config: GeneratorConfig

    static func defaultProject() -> Project {
        Project(
            id: UUID(),
            name: "My App",
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
                    ScreenshotEntry(id: "02", rawImage: "02-screenshot.png",
                                    caption: "Another great\nfeature",
                                    supportText: "Describe what makes it special"),
                    ScreenshotEntry(id: "03", rawImage: "03-screenshot.png",
                                    caption: "One more thing\nto show",
                                    supportText: "The finishing touch"),
                ]
            )
        )
    }
}
```

**Step 2: Verify it compiles**

Run: `swift build --product ScreenshotGenUI 2>&1 | tail -5`
Expected: Build Succeeded

**Step 3: Commit**

```bash
git add Sources/ScreenshotGenUI/Project.swift
git commit -m "feat: add Project model for folder-free app UX"
```

---

### Task 2: Create ProjectStore

Replaces the old `ProjectState.swift`. Manages project CRUD, image storage, and auto-save. Uses `~/Library/Application Support/ScreenshotGen/projects/` for persistence.

**Files:**
- Create: `Sources/ScreenshotGenUI/ProjectStore.swift` (replacing old `ProjectState.swift`)
- Delete content of: `Sources/ScreenshotGenUI/ProjectState.swift` (will be removed in later task)

**Step 1: Write ProjectStore**

```swift
import Foundation
import AppKit
import Observation
import ScreenshotGenCore

@Observable
@MainActor
final class ProjectStore {
    // MARK: - State

    var projects: [Project] = []
    var selectedProjectId: UUID?
    var selectedSlotIndex: Int?
    var logOutput: String = ""
    var isGenerating = false
    var errorMessage: String?
    var previewDeviceId: String?

    private var saveTask: Task<Void, Never>?

    // MARK: - Derived

    var selectedProject: Project? {
        get {
            projects.first { $0.id == selectedProjectId }
        }
        set {
            guard let newValue, let index = projects.firstIndex(where: { $0.id == newValue.id }) else { return }
            projects[index] = newValue
        }
    }

    var config: GeneratorConfig? {
        get { selectedProject?.config }
        set {
            guard let newValue else { return }
            selectedProject?.config = newValue
        }
    }

    var projectDir: URL? {
        guard let id = selectedProjectId else { return nil }
        return Self.projectsDir.appendingPathComponent(id.uuidString)
    }

    var rawDir: URL? {
        projectDir?.appendingPathComponent("RawScreenshots")
    }

    var previewSpec: DeviceSpec? {
        if let id = previewDeviceId, let spec = DeviceSpec.from(id) {
            return spec
        }
        return config?.devices.compactMap({ DeviceSpec.from($0) }).first
    }

    // MARK: - Paths

    static var appSupportDir: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ScreenshotGen")
    }

    static var projectsDir: URL {
        appSupportDir.appendingPathComponent("projects")
    }

    // MARK: - Init

    init() {
        loadAllProjects()
        if projects.isEmpty {
            let defaultProject = Project.defaultProject()
            projects.append(defaultProject)
            save(defaultProject)
            selectedProjectId = defaultProject.id
        } else {
            // Restore last selected project
            if let savedId = UserDefaults.standard.string(forKey: "selectedProjectId"),
               let uuid = UUID(uuidString: savedId),
               projects.contains(where: { $0.id == uuid }) {
                selectedProjectId = uuid
            } else {
                selectedProjectId = projects.first?.id
            }
        }
    }

    // MARK: - CRUD

    func createProject(name: String = "New Project") {
        var project = Project.defaultProject()
        project.name = name
        projects.append(project)
        save(project)
        selectedProjectId = project.id
        selectedSlotIndex = nil
    }

    func deleteProject(_ id: UUID) {
        let dir = Self.projectsDir.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: dir)
        projects.removeAll { $0.id == id }
        if selectedProjectId == id {
            selectedProjectId = projects.first?.id
            selectedSlotIndex = nil
        }
    }

    func renameProject(_ id: UUID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
        save(projects[index])
    }

    // MARK: - Persistence

    private func loadAllProjects() {
        let fm = FileManager.default
        let dir = Self.projectsDir

        guard fm.fileExists(atPath: dir.path) else { return }

        do {
            let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for folder in contents where folder.hasDirectoryPath {
                let projectFile = folder.appendingPathComponent("project.json")
                guard fm.fileExists(atPath: projectFile.path) else { continue }
                do {
                    let data = try Data(contentsOf: projectFile)
                    let project = try JSONDecoder().decode(Project.self, from: data)
                    projects.append(project)
                } catch {
                    // Skip corrupt projects
                }
            }
        } catch {
            // Directory read failed
        }

        projects.sort { $0.createdAt < $1.createdAt }
    }

    func save(_ project: Project) {
        let fm = FileManager.default
        let dir = Self.projectsDir.appendingPathComponent(project.id.uuidString)
        let rawDir = dir.appendingPathComponent("RawScreenshots")

        do {
            try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(project)
            try data.write(to: dir.appendingPathComponent("project.json"), options: .atomic)
        } catch {
            errorMessage = "Failed to save project: \(error.localizedDescription)"
        }
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let project = selectedProject else { return }
            save(project)
        }
    }

    // MARK: - Image Helpers

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

    func importImage(from sourceURL: URL, toSlotIndex index: Int) {
        guard let rawDir, let config, index < config.screenshots.count else { return }
        let entry = config.screenshots[index]
        let destURL = rawDir.appendingPathComponent(entry.rawImage)
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
        } catch {
            errorMessage = "Failed to import image: \(error.localizedDescription)"
        }
    }

    // MARK: - Slot Management

    func addSlot() {
        guard config != nil else { return }
        let nextNumber = config!.screenshots.count + 1
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

    // MARK: - Selection Persistence

    func persistSelection() {
        if let id = selectedProjectId {
            UserDefaults.standard.set(id.uuidString, forKey: "selectedProjectId")
        }
    }
}
```

**Step 2: Verify it compiles** (it won't build the full product yet since ContentView still references old ProjectState, but the file itself should be syntax-valid)

Run: `swift build --product ScreenshotGenUI 2>&1 | tail -10`
Expected: Errors about `ProjectState` not found (expected — we'll fix in next tasks)

**Step 3: Commit**

```bash
git add Sources/ScreenshotGenUI/ProjectStore.swift
git commit -m "feat: add ProjectStore for Application Support-backed persistence"
```

---

### Task 3: Delete Old ProjectState

**Files:**
- Delete: `Sources/ScreenshotGenUI/ProjectState.swift`

**Step 1: Remove the file**

```bash
rm Sources/ScreenshotGenUI/ProjectState.swift
```

**Step 2: Commit**

```bash
git add -u Sources/ScreenshotGenUI/ProjectState.swift
git commit -m "chore: remove old ProjectState (replaced by ProjectStore)"
```

---

### Task 4: Update ScreenshotGenUIApp

**Files:**
- Modify: `Sources/ScreenshotGenUI/ScreenshotGenUIApp.swift`

**Step 1: Replace the app entry point to use ProjectStore**

Replace the entire file:

```swift
import SwiftUI
import AppKit
import ScreenshotGenCore

@main
struct ScreenshotGenUIApp: App {
    @State private var store = ProjectStore()

    init() {
        if !Bundle.main.bundlePath.hasSuffix(".app") {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
    }
}
```

Key changes: `ProjectState` → `ProjectStore`, removed `loadIfNeeded()` call (store loads in init).

**Step 2: Don't build yet** — ContentView needs updating first.

**Step 3: Commit**

```bash
git add Sources/ScreenshotGenUI/ScreenshotGenUIApp.swift
git commit -m "feat: update app entry point to use ProjectStore"
```

---

### Task 5: Update ContentView with Project Sidebar

The main UI change. Replace the "Select Project Folder" empty state with a three-column layout: project list | slot list | editor.

**Files:**
- Modify: `Sources/ScreenshotGenUI/ContentView.swift`

**Step 1: Rewrite ContentView**

Replace the entire file:

```swift
import SwiftUI
import AppKit
import ScreenshotGenCore

enum BottomTab: String, CaseIterable {
    case preview = "Preview"
    case log = "Log"
}

struct ContentView: View {
    @Environment(ProjectStore.self) private var store
    @State private var showImportSheet = false
    @State private var bottomTab: BottomTab = .preview

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            ProjectListView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } content: {
            if store.selectedProject != nil {
                SlotListView()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } else {
                Text("Select a project")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            VStack(spacing: 0) {
                if store.selectedSlotIndex != nil, store.config != nil {
                    EditorPanel()
                } else {
                    Text("Select a screenshot slot")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                BottomPanel(tab: $bottomTab)
                    .environment(store)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.config != nil {
                    Button("Import Images") {
                        showImportSheet = true
                    }
                    .help("Import screenshot images")

                    Button {
                        store.runGenerate()
                    } label: {
                        if store.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Generate", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(store.isGenerating)
                    .help("Generate App Store screenshots")
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportView()
                .environment(store)
        }
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.isGenerating) { _, isGenerating in
            if isGenerating {
                bottomTab = .log
            }
        }
        .onChange(of: store.selectedProjectId) {
            store.persistSelection()
        }
    }
}
```

Key changes:
- `ProjectState` → `ProjectStore` throughout
- `NavigationSplitView` now three-column (project list | slots | editor)
- Removed "Select Project Folder" empty state — always shows project list
- Removed "Open Project" toolbar button and "Save" button (auto-save)
- Removed `state.selectProjectFolder()` calls

**Step 2: Don't build yet** — need ProjectListView and other updates.

**Step 3: Commit**

```bash
git add Sources/ScreenshotGenUI/ContentView.swift
git commit -m "feat: replace folder picker with three-column project sidebar"
```

---

### Task 6: Create ProjectListView

New sidebar view showing all projects with create/delete/rename.

**Files:**
- Create: `Sources/ScreenshotGenUI/ProjectListView.swift`

**Step 1: Write ProjectListView**

```swift
import SwiftUI

struct ProjectListView: View {
    @Environment(ProjectStore.self) private var store
    @State private var renamingId: UUID?
    @State private var renameText: String = ""

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedProjectId) {
            ForEach(store.projects) { project in
                projectRow(project)
                    .tag(project.id)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button {
                        store.createProject()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("New project")

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(.bar)
        }
        .navigationTitle("Projects")
        .onChange(of: store.selectedProjectId) {
            store.selectedSlotIndex = nil
        }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        if renamingId == project.id {
            TextField("Project name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    store.renameProject(project.id, to: renameText)
                    renamingId = nil
                }
                .onExitCommand {
                    renamingId = nil
                }
        } else {
            Text(project.name)
                .contextMenu {
                    Button("Rename...") {
                        renameText = project.name
                        renamingId = project.id
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        store.deleteProject(project.id)
                    }
                    .disabled(store.projects.count <= 1)
                }
        }
    }
}
```

**Step 2: Don't build yet** — SlotListView and EditorPanel still reference old types.

**Step 3: Commit**

```bash
git add Sources/ScreenshotGenUI/ProjectListView.swift
git commit -m "feat: add ProjectListView sidebar for multi-project navigation"
```

---

### Task 7: Update SlotListView (ProjectState → ProjectStore + drag-and-drop)

**Files:**
- Modify: `Sources/ScreenshotGenUI/SlotListView.swift`

**Step 1: Update to use ProjectStore and add drop support**

Replace the entire file:

```swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ScreenshotGenCore

struct SlotListView: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedSlotIndex) {
            if let config = store.config {
                ForEach(Array(config.screenshots.enumerated()), id: \.element.id) { index, entry in
                    SlotRow(entry: entry, exists: store.rawImageExists(for: entry), thumbnail: store.thumbnail(for: entry))
                        .tag(index)
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers, slotIndex: index)
                        }
                }
                .onMove { source, destination in
                    store.moveSlot(from: source, to: destination)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button {
                        store.addSlot()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("Add screenshot slot")

                    Button {
                        if let index = store.selectedSlotIndex {
                            store.removeSlot(at: index)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.selectedSlotIndex == nil)
                    .help("Remove selected slot")

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(.bar)
        }
        .navigationTitle("Screenshots")
    }

    private func handleDrop(providers: [NSItemProvider], slotIndex: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]
            guard imageExtensions.contains(url.pathExtension.lowercased()) else { return }
            Task { @MainActor in
                store.importImage(from: url, toSlotIndex: slotIndex)
            }
        }
        return true
    }
}

struct SlotRow: View {
    let entry: ScreenshotEntry
    let exists: Bool
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 40, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.id)
                        .font(.headline)
                    Circle()
                        .fill(exists ? .green : .red)
                        .frame(width: 8, height: 8)
                }

                Text(entry.rawImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.caption.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```

Key changes: `ProjectState` → `ProjectStore`, added `.onDrop` per slot row.

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/SlotListView.swift
git commit -m "feat: update SlotListView with drag-and-drop image import"
```

---

### Task 8: Update EditorPanel (ProjectState → ProjectStore)

**Files:**
- Modify: `Sources/ScreenshotGenUI/EditorPanel.swift`

**Step 1: Replace all `ProjectState` references with `ProjectStore`**

This is a find-and-replace: change `@Environment(ProjectState.self)` to `@Environment(ProjectStore.self)` and `state` to `store` throughout. Also update `chooseFileForSlot` to use `store.importImage`.

Change line 6:
```swift
@Environment(ProjectStore.self) private var store
```

Change line 10:
```swift
@Bindable var store = store
```

Then replace all `state.` with `store.` throughout the file.

Update `chooseFileForSlot` (around line 313):
```swift
private func chooseFileForSlot(index: Int) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.png, .jpeg, .heic]
    panel.message = "Select a screenshot image"

    guard panel.runModal() == .OK, let url = panel.url else { return }
    store.importImage(from: url, toSlotIndex: index)
}
```

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/EditorPanel.swift
git commit -m "refactor: update EditorPanel to use ProjectStore"
```

---

### Task 9: Update ImportView (ProjectState → ProjectStore)

**Files:**
- Modify: `Sources/ScreenshotGenUI/ImportView.swift`

**Step 1: Replace ProjectState with ProjectStore**

Change `@Environment(ProjectState.self)` to `@Environment(ProjectStore.self)` and `state` to `store` throughout.

Update the Import button action to use `store.importImage` for each assignment:

```swift
Button("Import") {
    for (index, url) in assignments {
        store.importImage(from: url, toSlotIndex: index)
    }
    dismiss()
}
```

Replace `state.autoAssignByDate` with a local implementation (move the method to ImportView or keep it on ProjectStore):

Add to `ProjectStore`:
```swift
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
```

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/ImportView.swift Sources/ScreenshotGenUI/ProjectStore.swift
git commit -m "refactor: update ImportView to use ProjectStore"
```

---

### Task 10: Update BottomPanel / PreviewPanel / LogPanel (in ContentView)

These views at the bottom of `ContentView.swift` reference `ProjectState`. Update them to use `ProjectStore`.

**Files:**
- Modify: `Sources/ScreenshotGenUI/ContentView.swift` (BottomPanel, PreviewPanel, LogPanelContent structs)

**Step 1: Replace all `ProjectState` with `ProjectStore` and `state` with `store`**

In `BottomPanel`, `PreviewPanel`, `FullPreviewSheet`, and `LogPanelContent`:
- `@Environment(ProjectState.self)` → `@Environment(ProjectStore.self)`
- All `state.` → `store.`
- Bindable vars: `@Bindable var state = state` → `@Bindable var store = store`

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/ContentView.swift
git commit -m "refactor: update bottom panels to use ProjectStore"
```

---

### Task 11: Add Auto-Save on Config Changes

Wire up `scheduleSave()` so changes to the config (editing captions, colors, devices, etc.) are automatically persisted.

**Files:**
- Modify: `Sources/ScreenshotGenUI/ContentView.swift` (add onChange)

**Step 1: Add onChange observer in ContentView body**

Add after the existing `.onChange` calls:

```swift
.onChange(of: store.config) {
    store.scheduleSave()
}
```

Note: This requires `GeneratorConfig` to be `Equatable` — it already is (declared in Config.swift).

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/ContentView.swift
git commit -m "feat: auto-save config changes with debounce"
```

---

### Task 12: Build, Run, and Verify

**Step 1: Build the product**

Run: `swift build --product ScreenshotGenUI 2>&1 | tail -10`
Expected: Build Succeeded

**Step 2: Run and manually verify**

Run: `swift run ScreenshotGenUI`

Verify:
- App opens immediately — no folder picker, no error
- Left sidebar shows "My App" project with 3 template slots
- Can create a new project with "+"
- Can right-click project to rename/delete
- Can click slots to edit captions, colors, devices
- Can drag an image from Finder onto a slot (green dot appears)
- Can click Generate, pick output folder, and generate screenshots
- Quit and relaunch — projects persist, last selection restored

**Step 3: Also verify CLI still works**

Run: `swift run ScreenshotGen`
Expected: CLI runs normally, reads config.json from current directory

**Step 4: Verify Xcode workflow**

Run: `make xcodegen && open ScreenshotGen.xcodeproj`
Then Cmd+R in Xcode — should launch without sandbox errors.

**Step 5: Commit any fixes from testing**

---

### Task 13: Update JSONDecoder for Project

The `Project` model uses `Date` which needs ISO8601 decoding to match the encoder.

**Files:**
- Modify: `Sources/ScreenshotGenUI/ProjectStore.swift`

**Step 1: Add dateDecodingStrategy in loadAllProjects**

In the `loadAllProjects` method, update the decoder:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let data = try Data(contentsOf: projectFile)
let project = try decoder.decode(Project.self, from: data)
```

**Step 2: Commit**

```bash
git add Sources/ScreenshotGenUI/ProjectStore.swift
git commit -m "fix: use ISO8601 date decoding for project files"
```
