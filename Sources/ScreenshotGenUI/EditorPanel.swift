import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ScreenshotGenCore

struct EditorPanel: View {
    @Environment(ProjectState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let index = state.selectedSlotIndex, let config = state.config,
                   index < config.screenshots.count {
                    slotEditor(index: index)
                }

                Divider()

                deviceSelector

                Divider()

                colorEditor
            }
            .padding(20)
        }
        .navigationTitle("Editor")
    }

    @ViewBuilder
    private func slotEditor(index: Int) -> some View {
        @Bindable var state = state

        let entry = state.config!.screenshots[index]

        VStack(alignment: .leading, spacing: 16) {
            Text("Slot \(entry.id)")
                .font(.title2.bold())

            LabeledContent("Raw Image") {
                HStack {
                    Text(entry.rawImage)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(state.rawImageExists(for: entry) ? .green : .red)
                        .frame(width: 8, height: 8)

                    Button("Choose File...") {
                        chooseFileForSlot(index: index)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Caption")
                    .font(.subheadline.bold())
                TextField("Caption", text: captionBinding(index: index), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                Text("Use line breaks for multi-line captions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Support Text")
                    .font(.subheadline.bold())
                TextField("Support text", text: supportTextBinding(index: index))
                    .textFieldStyle(.roundedBorder)
            }

            // Preview thumbnail
            if let thumb = state.thumbnail(for: entry) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw Image Preview")
                        .font(.subheadline.bold())
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)
                }
            }
        }
    }

    @ViewBuilder
    private var deviceSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Devices")
                .font(.title2.bold())

            if state.config != nil {
                HStack(alignment: .top, spacing: 24) {
                    deviceCategoryList("iPhone", categories: DisplayCategory.iPhoneCategories)
                    deviceCategoryList("iPad", categories: DisplayCategory.iPadCategories)
                }
            }
        }
    }

    @ViewBuilder
    private func deviceCategoryList(_ platform: String, categories: [DisplayCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(platform)
                .font(.headline)
                .padding(.top, 4)

            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.subheadline.bold())
                    Text(category.devices)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(category.specs) { spec in
                        Toggle(isOn: deviceToggle(for: spec.id)) {
                            HStack(spacing: 6) {
                                Text("\(spec.pixelWidth)x\(spec.pixelHeight)")
                                    .font(.body.monospacedDigit())
                                Text(spec.deviceName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var colorEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colors")
                .font(.title2.bold())

            if state.config != nil {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    colorField(title: "Gradient Top", hexKeyPath: \.gradientTopColor)
                    colorField(title: "Gradient Bottom", hexKeyPath: \.gradientBottomColor)
                    colorField(title: "Text Color", hexKeyPath: \.textColor)
                }

                HStack {
                    Text("Support Text Opacity")
                        .font(.subheadline)
                    Slider(value: opacityBinding, in: 0...1, step: 0.05)
                    Text(String(format: "%.0f%%", (state.config?.resolvedSupportTextOpacity ?? 0.8) * 100))
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
    }

    @ViewBuilder
    private func colorField(title: String, hexKeyPath: WritableKeyPath<GeneratorConfig, String>) -> some View {
        if state.config != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                HStack {
                    ColorPicker(
                        "",
                        selection: colorBinding(for: hexKeyPath),
                        supportsOpacity: false
                    )
                    .labelsHidden()

                    TextField("Hex", text: hexBinding(for: hexKeyPath))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Bindings

    private func deviceToggle(for deviceId: String) -> Binding<Bool> {
        Binding(
            get: {
                state.config?.devices.contains(deviceId) ?? false
            },
            set: { isOn in
                guard state.config != nil else { return }
                if isOn {
                    if !state.config!.devices.contains(deviceId) {
                        state.config!.devices.append(deviceId)
                    }
                } else {
                    state.config!.devices.removeAll { $0 == deviceId }
                }
            }
        )
    }

    private func captionBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let config = state.config, index < config.screenshots.count else { return "" }
                return config.screenshots[index].caption
            },
            set: { newValue in
                state.config?.screenshots[index].caption = newValue
            }
        )
    }

    private func supportTextBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let config = state.config, index < config.screenshots.count else { return "" }
                return config.screenshots[index].supportText
            },
            set: { newValue in
                state.config?.screenshots[index].supportText = newValue
            }
        )
    }

    private func colorBinding(for keyPath: WritableKeyPath<GeneratorConfig, String>) -> Binding<Color> {
        Binding(
            get: {
                guard let config = state.config else { return .white }
                return Color(hex: config[keyPath: keyPath])
            },
            set: { newValue in
                state.config?[keyPath: keyPath] = newValue.hexString
            }
        )
    }

    private func hexBinding(for keyPath: WritableKeyPath<GeneratorConfig, String>) -> Binding<String> {
        Binding(
            get: {
                state.config?[keyPath: keyPath] ?? "#000000"
            },
            set: { newValue in
                state.config?[keyPath: keyPath] = newValue
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { state.config?.resolvedSupportTextOpacity ?? 0.8 },
            set: { state.config?.supportTextOpacity = $0 }
        )
    }

    // MARK: - File picker for individual slot

    private func chooseFileForSlot(index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.message = "Select a screenshot image"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.importImages(from: [url], assignments: [index: url])
    }
}
