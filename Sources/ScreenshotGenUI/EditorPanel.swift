import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ScreenshotGenCore

struct EditorPanel: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let _ = store.imageRevision // trigger re-render on image import

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let index = store.selectedSlotIndex, let config = store.config,
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
        @Bindable var store = store

        let entry = store.config!.screenshots[index]

        VStack(alignment: .leading, spacing: 16) {
            Text("Slot \(entry.id)")
                .font(.title2.bold())

            LabeledContent("Raw Image") {
                HStack {
                    Text(entry.rawImage)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(store.rawImageExists(for: entry) ? .green : .red)
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
            if let thumb = store.thumbnail(for: entry) {
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

            if store.config != nil {
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
                    HStack(spacing: 6) {
                        categoryToggleButton(for: category)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.subheadline.bold())
                            Text(category.devices)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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

            if store.config != nil {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    colorField(title: "Gradient Top", hexKeyPath: \.gradientTopColor)
                    colorField(title: "Gradient Bottom", hexKeyPath: \.gradientBottomColor)
                    colorField(title: "Text Color", hexKeyPath: \.textColor)
                }

                HStack {
                    Text("Support Text Opacity")
                        .font(.subheadline)
                    Slider(value: opacityBinding, in: 0...1, step: 0.05)
                    Text(String(format: "%.0f%%", (store.config?.resolvedSupportTextOpacity ?? 0.8) * 100))
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
    }

    @ViewBuilder
    private func colorField(title: String, hexKeyPath: WritableKeyPath<GeneratorConfig, String>) -> some View {
        if store.config != nil {
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

    // MARK: - Category Toggle

    private enum CategorySelection {
        case all, some, none
    }

    private func categorySelection(for category: DisplayCategory) -> CategorySelection {
        guard let devices = store.config?.devices else { return .none }
        let specIds = category.specs.map(\.id)
        let selectedCount = specIds.filter { devices.contains($0) }.count
        if selectedCount == specIds.count { return .all }
        if selectedCount > 0 { return .some }
        return .none
    }

    @ViewBuilder
    private func categoryToggleButton(for category: DisplayCategory) -> some View {
        let selection = categorySelection(for: category)
        Button {
            toggleCategory(category)
        } label: {
            Image(systemName: selection == .all ? "checkmark.square.fill" :
                             selection == .some ? "minus.square.fill" : "square")
                .foregroundStyle(selection == .none ? .secondary : .primary)
                .imageScale(.large)
        }
        .buttonStyle(.plain)
        .help(selection == .all ? "Deselect all \(category.name)" : "Select all \(category.name)")
    }

    private func toggleCategory(_ category: DisplayCategory) {
        guard store.config != nil else { return }
        let selection = categorySelection(for: category)
        let specIds = category.specs.map(\.id)

        if selection == .all {
            store.config!.devices.removeAll { specIds.contains($0) }
        } else {
            for id in specIds where !store.config!.devices.contains(id) {
                store.config!.devices.append(id)
            }
        }
    }

    // MARK: - Bindings

    private func deviceToggle(for deviceId: String) -> Binding<Bool> {
        Binding(
            get: {
                store.config?.devices.contains(deviceId) ?? false
            },
            set: { isOn in
                guard store.config != nil else { return }
                if isOn {
                    if !store.config!.devices.contains(deviceId) {
                        store.config!.devices.append(deviceId)
                    }
                } else {
                    store.config!.devices.removeAll { $0 == deviceId }
                }
            }
        )
    }

    private func captionBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let config = store.config, index < config.screenshots.count else { return "" }
                return config.screenshots[index].caption
            },
            set: { newValue in
                store.config?.screenshots[index].caption = newValue
            }
        )
    }

    private func supportTextBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let config = store.config, index < config.screenshots.count else { return "" }
                return config.screenshots[index].supportText
            },
            set: { newValue in
                store.config?.screenshots[index].supportText = newValue
            }
        )
    }

    private func colorBinding(for keyPath: WritableKeyPath<GeneratorConfig, String>) -> Binding<Color> {
        Binding(
            get: {
                guard let config = store.config else { return .white }
                return Color(hex: config[keyPath: keyPath])
            },
            set: { newValue in
                store.config?[keyPath: keyPath] = newValue.hexString
            }
        )
    }

    private func hexBinding(for keyPath: WritableKeyPath<GeneratorConfig, String>) -> Binding<String> {
        Binding(
            get: {
                store.config?[keyPath: keyPath] ?? "#000000"
            },
            set: { newValue in
                store.config?[keyPath: keyPath] = newValue
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { store.config?.resolvedSupportTextOpacity ?? 0.8 },
            set: { store.config?.supportTextOpacity = $0 }
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
        store.importImage(from: url, toSlotIndex: index)
    }
}
