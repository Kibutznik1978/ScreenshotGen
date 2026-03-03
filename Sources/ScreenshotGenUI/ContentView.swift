import SwiftUI
import AppKit
import ScreenshotGenCore

enum BottomTab: String, CaseIterable {
    case preview = "Preview"
    case log = "Log"
}

struct ContentView: View {
    @Environment(ProjectState.self) private var state
    @State private var showImportSheet = false
    @State private var bottomTab: BottomTab = .preview

    var body: some View {
        Group {
            if state.config != nil {
                NavigationSplitView {
                    SlotListView()
                        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
                } detail: {
                    VStack(spacing: 0) {
                        if state.selectedSlotIndex != nil {
                            EditorPanel()
                        } else {
                            Text("Select a screenshot slot")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        BottomPanel(tab: $bottomTab)
                            .environment(state)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No project loaded")
                        .font(.title2)
                    Text("Select a project folder containing config.json")
                        .foregroundStyle(.secondary)
                    Button("Select Project Folder...") {
                        state.selectProjectFolder()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    state.selectProjectFolder()
                } label: {
                    Label("Open Project", systemImage: "folder")
                }
                .help("Open project folder")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if state.config != nil {
                    Button("Import Images") {
                        showImportSheet = true
                    }
                    .help("Import screenshot images")

                    Button("Save") {
                        state.saveConfig()
                    }
                    .help("Save config.json")

                    Button {
                        state.runGenerate()
                    } label: {
                        if state.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Generate", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(state.isGenerating)
                    .help("Generate App Store screenshots")
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportView()
                .environment(state)
        }
        .alert("Error", isPresented: .init(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .onChange(of: state.isGenerating) { _, isGenerating in
            if isGenerating {
                bottomTab = .log
            }
        }
    }
}

// MARK: - Bottom Panel

struct BottomPanel: View {
    @Environment(ProjectState.self) private var state
    @Binding var tab: BottomTab

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            Picker("", selection: $tab) {
                ForEach(BottomTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .padding(.vertical, 6)

            switch tab {
            case .preview:
                PreviewPanel()
                    .environment(state)
            case .log:
                LogPanelContent()
                    .environment(state)
            }
        }
        .frame(height: 220)
        .background(.regularMaterial)
    }
}

// MARK: - Preview Panel

struct PreviewPanel: View {
    @Environment(ProjectState.self) private var state
    @State private var showFullPreview = false

    var body: some View {
        @Bindable var state = state

        Group {
            if let config = state.config,
               let slotIndex = state.selectedSlotIndex,
               slotIndex < config.screenshots.count,
               let spec = state.previewSpec,
               let rawURL = state.rawImageURL(for: config.screenshots[slotIndex]),
               let screenshot = NSImage(contentsOf: rawURL) {
                HStack(spacing: 12) {
                    // Scaled preview — click to enlarge
                    GeometryReader { geo in
                        let entry = config.screenshots[slotIndex]
                        ScreenshotView(entry: entry, screenshot: screenshot, spec: spec, config: config)
                            .frame(width: spec.canvasWidth, height: spec.canvasHeight)
                            .scaleEffect(geo.size.height / spec.canvasHeight)
                            .frame(width: spec.canvasWidth * (geo.size.height / spec.canvasHeight), height: geo.size.height)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { showFullPreview = true }
                            .help("Click to enlarge")
                    }
                    .cursor(.pointingHand)

                    // Device picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview Device")
                            .font(.caption.bold())
                        Picker("Device", selection: previewDeviceBinding) {
                            ForEach(state.config?.resolvedDevices ?? [], id: \.id) { spec in
                                Text(spec.label).tag(spec.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 12)
                .sheet(isPresented: $showFullPreview) {
                    FullPreviewSheet(entry: config.screenshots[slotIndex], screenshot: screenshot, spec: spec, config: config)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(previewPlaceholderMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var previewDeviceBinding: Binding<String> {
        Binding(
            get: { state.previewSpec?.id ?? "" },
            set: { state.previewDeviceId = $0 }
        )
    }

    private var previewPlaceholderMessage: String {
        if state.selectedSlotIndex == nil {
            return "Select a screenshot slot to preview"
        }
        if state.config?.devices.isEmpty ?? true {
            return "Select at least one device to preview"
        }
        if let index = state.selectedSlotIndex,
           let config = state.config,
           index < config.screenshots.count,
           !state.rawImageExists(for: config.screenshots[index]) {
            return "Add a raw image to this slot to preview"
        }
        return "No preview available"
    }
}

// MARK: - Full Preview Sheet

struct FullPreviewSheet: View {
    let entry: ScreenshotEntry
    let screenshot: NSImage
    let spec: DeviceSpec
    let config: GeneratorConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(entry.id) — \(spec.label)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            GeometryReader { geo in
                let scale = min(geo.size.width / spec.canvasWidth, geo.size.height / spec.canvasHeight)
                ScreenshotView(entry: entry, screenshot: screenshot, spec: spec, config: config)
                    .frame(width: spec.canvasWidth, height: spec.canvasHeight)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 700)
    }
}

// MARK: - Cursor Helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Log Panel

struct LogPanelContent: View {
    @Environment(ProjectState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if state.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    state.logOutput = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(state.isGenerating)
                .help("Clear log")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            ScrollView {
                Text(state.logOutput.isEmpty ? "No output yet" : state.logOutput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(state.logOutput.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(.background)
        }
    }
}
