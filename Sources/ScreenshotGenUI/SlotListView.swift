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
            // Thumbnail or placeholder
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
