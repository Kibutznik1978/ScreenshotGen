import SwiftUI
import ScreenshotGenCore

struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        List(selection: $state.selectedEntryID) {
            ForEach(state.entries) { entry in
                SidebarRow(entry: entry)
                    .tag(entry.id)
            }
            .onMove { source, destination in
                state.moveEntries(from: source, to: destination)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    state.addEntry()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                if let selectedID = state.selectedEntryID {
                    Button(role: .destructive) {
                        state.removeEntry(selectedID)
                    } label: {
                        Label("Remove", systemImage: "minus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
        }
    }
}

struct SidebarRow: View {
    let entry: ScreenshotEntryModel

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if let image = entry.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.caption.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(entry.rawImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
