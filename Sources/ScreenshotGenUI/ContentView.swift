import SwiftUI
import ScreenshotGenCore

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            HSplitView {
                PreviewPanel()
                    .frame(minWidth: 350)

                InspectorPanel()
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                DevicePicker()

                Button {
                    state.saveConfigFile()
                } label: {
                    Label("Save Config", systemImage: "square.and.arrow.down")
                }
                .help("Save config.json")

                Button {
                    state.exportAll()
                } label: {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }
                .help("Export all screenshots to Output/")
                .disabled(state.entries.isEmpty || state.isExporting)
            }

            ToolbarItem(placement: .automatic) {
                if !state.exportMessage.isEmpty {
                    Text(state.exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DevicePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Picker("Preview", selection: $state.previewDevice) {
            ForEach(DeviceSpec.allCases) { device in
                Text(device.label).tag(device)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}
