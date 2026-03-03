import SwiftUI
import ScreenshotGenCore

struct InspectorPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Screenshot-specific fields
                if let selectedID = state.selectedEntryID,
                   let idx = state.entries.firstIndex(where: { $0.id == selectedID }) {

                    screenshotSection(index: idx)
                }

                Divider()

                // Global appearance
                appearanceSection()

                Divider()

                // Devices
                devicesSection()

                Divider()

                // Project
                projectSection()
            }
            .padding()
        }
        .background(.background)
    }

    // MARK: - Screenshot Section

    @ViewBuilder
    private func screenshotSection(index: Int) -> some View {
        @Bindable var state = state

        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Image picker
                HStack {
                    if let image = state.entries[index].image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(width: 48, height: 80)
                            .overlay {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.entries[index].rawImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Button("Choose Image...") {
                            state.pickImage(for: state.entries[index].id)
                        }
                        .controlSize(.small)
                    }
                }

                // Caption
                VStack(alignment: .leading, spacing: 4) {
                    Text("Caption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $state.entries[index].caption)
                        .font(.body)
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                }

                // Support text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Support Text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Support text", text: $state.entries[index].supportText)
                        .textFieldStyle(.roundedBorder)
                }

                // Entry ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("ID", text: $state.entries[index].id)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        } header: {
            Text("Screenshot")
                .font(.headline)
        }
    }

    // MARK: - Appearance Section

    @ViewBuilder
    private func appearanceSection() -> some View {
        @Bindable var state = state

        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ColorPicker("Top", selection: $state.gradientTopColor, supportsOpacity: false)
                    Spacer()
                    ColorPicker("Bottom", selection: $state.gradientBottomColor, supportsOpacity: false)
                }

                ColorPicker("Text Color", selection: $state.textColor, supportsOpacity: false)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Support Text Opacity: \(state.supportTextOpacity, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $state.supportTextOpacity, in: 0...1, step: 0.05)
                }
            }
        } header: {
            Text("Appearance")
                .font(.headline)
        }
    }

    // MARK: - Devices Section

    @ViewBuilder
    private func devicesSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(DeviceSpec.allCases) { device in
                    Toggle(device.label, isOn: Binding(
                        get: { state.enabledDevices.contains(device) },
                        set: { enabled in
                            if enabled {
                                state.enabledDevices.insert(device)
                            } else if state.enabledDevices.count > 1 {
                                state.enabledDevices.remove(device)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
        } header: {
            Text("Export Devices")
                .font(.headline)
        }
    }

    // MARK: - Project Section

    @ViewBuilder
    private func projectSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(state.projectDir.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button("Choose Folder...") {
                    state.chooseProjectFolder()
                }
                .controlSize(.small)
            }
        } header: {
            Text("Project Folder")
                .font(.headline)
        }
    }
}
