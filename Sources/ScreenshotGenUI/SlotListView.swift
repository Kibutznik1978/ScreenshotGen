import SwiftUI
import AppKit
import ScreenshotGenCore

struct SlotListView: View {
    @Environment(ProjectState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            List(selection: $state.selectedSlotIndex) {
                if let config = state.config {
                    ForEach(Array(config.screenshots.enumerated()), id: \.offset) { index, entry in
                        SlotRow(entry: entry, exists: state.rawImageExists(for: entry), thumbnail: state.thumbnail(for: entry))
                            .tag(index)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 0) {
                Button {
                    state.addSlot()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Add screenshot slot")

                Button {
                    if let index = state.selectedSlotIndex {
                        state.removeSlot(at: index)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(state.selectedSlotIndex == nil)
                .help("Remove selected slot")

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .navigationTitle("Screenshots")
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
