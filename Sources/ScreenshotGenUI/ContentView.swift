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
                if store.selectedSlotIndex != nil {
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
        .onChange(of: store.config) {
            store.scheduleSave()
        }
        .onChange(of: store.selectedProjectId) {
            store.persistSelection()
        }
    }
}

// MARK: - Bottom Panel

struct BottomPanel: View {
    @Environment(ProjectStore.self) private var store
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
                    .environment(store)
            case .log:
                LogPanelContent()
                    .environment(store)
            }
        }
        .frame(height: 220)
        .background(.regularMaterial)
    }
}

// MARK: - Preview Panel

struct PreviewPanel: View {
    @Environment(ProjectStore.self) private var store
    @State private var showFullPreview = false

    var body: some View {
        @Bindable var store = store
        let _ = store.imageRevision // trigger re-render on image import

        Group {
            if let config = store.config,
               let slotIndex = store.selectedSlotIndex,
               slotIndex < config.screenshots.count,
               let spec = store.previewSpec,
               let rawURL = store.rawImageURL(for: config.screenshots[slotIndex]),
               let screenshot = NSImage(contentsOf: rawURL) {
                HStack(spacing: 12) {
                    // Scaled preview -- click to enlarge
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
                            ForEach(store.config?.resolvedDevices ?? [], id: \.id) { spec in
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
            get: { store.previewSpec?.id ?? "" },
            set: { store.previewDeviceId = $0 }
        )
    }

    private var previewPlaceholderMessage: String {
        if store.selectedSlotIndex == nil {
            return "Select a screenshot slot to preview"
        }
        if store.config?.devices.isEmpty ?? true {
            return "Select at least one device to preview"
        }
        if let index = store.selectedSlotIndex,
           let config = store.config,
           index < config.screenshots.count,
           !store.rawImageExists(for: config.screenshots[index]) {
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
    @Environment(ProjectStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if store.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    store.logOutput = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(store.isGenerating)
                .help("Clear log")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            ScrollView {
                Text(store.logOutput.isEmpty ? "No output yet" : store.logOutput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(store.logOutput.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(.background)
        }
    }
}
