import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ScreenshotGenCore

struct ImportView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sourceImages: [URL] = []
    @State private var assignments: [Int: URL] = [:]
    @State private var mode: ImportMode = .auto

    enum ImportMode: String, CaseIterable {
        case auto = "Auto-assign (by date)"
        case manual = "Manual assignment"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Screenshots")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Step 1: Select source folder
                HStack {
                    Text("1. Select a folder of images")
                        .font(.headline)
                    Spacer()
                    Button("Choose Folder...") {
                        selectFolder()
                    }
                }

                if !sourceImages.isEmpty {
                    Text("\(sourceImages.count) images found")
                        .foregroundStyle(.secondary)

                    // Step 2: Assignment mode
                    Picker("2. Assignment mode", selection: $mode) {
                        ForEach(ImportMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) {
                        if mode == .auto {
                            assignments = store.autoAssignByDate(images: sourceImages)
                        } else {
                            assignments = [:]
                        }
                    }

                    // Step 3: Show assignments
                    Text("3. Review assignments")
                        .font(.headline)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if let config = store.config {
                                ForEach(Array(config.screenshots.enumerated()), id: \.offset) { index, entry in
                                    assignmentRow(index: index, entry: entry)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Import") {
                    for (slotIndex, sourceURL) in assignments {
                        store.importImage(from: sourceURL, toSlotIndex: slotIndex)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(assignments.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private func assignmentRow(index: Int, entry: ScreenshotEntry) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Slot \(entry.id)")
                    .font(.subheadline.bold())
                Text(entry.rawImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .leading)

            Image(systemName: "arrow.left")
                .foregroundStyle(.secondary)

            if let assigned = assignments[index] {
                Text(assigned.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Button {
                    assignments.removeValue(forKey: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Not assigned")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if mode == .manual {
                Menu("Choose...") {
                    ForEach(sourceImages, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            assignments[index] = url
                        }
                    }
                }
                .frame(width: 100)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(assignments[index] != nil ? Color.green.opacity(0.1) : Color.clear)
        )
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing screenshot images"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fm = FileManager.default
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]

        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey])
            sourceImages = contents.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            sourceImages = []
        }

        if mode == .auto {
            assignments = store.autoAssignByDate(images: sourceImages)
        }
    }
}
