import SwiftUI
import ScreenshotGenCore

struct ContentView: View {
    @Environment(ProjectState.self) private var state
    @State private var showImportSheet = false

    var body: some View {
        Group {
            if state.config != nil {
                NavigationSplitView {
                    SlotListView()
                        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
                } detail: {
                    if state.selectedSlotIndex != nil {
                        EditorPanel()
                    } else {
                        Text("Select a screenshot slot")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .overlay(alignment: .bottom) {
            if state.isGenerating || !state.logOutput.isEmpty {
                LogPanel()
                    .environment(state)
            }
        }
    }
}

struct LogPanel: View {
    @Environment(ProjectState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Text("Output")
                    .font(.headline)
                Spacer()
                if state.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    state.logOutput = ""
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .disabled(state.isGenerating)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView {
                Text(state.logOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .frame(height: 160)
            .background(.background)
        }
        .background(.regularMaterial)
    }
}
