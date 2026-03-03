import SwiftUI
import AppKit
import ScreenshotGenCore

struct PreviewPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if let entry = state.selectedEntry, let image = entry.image {
                let screenshotEntry = ScreenshotEntry(
                    id: entry.id,
                    rawImage: entry.rawImage,
                    caption: entry.caption,
                    supportText: entry.supportText
                )

                ScrollView([.horizontal, .vertical]) {
                    ScreenshotView(
                        entry: screenshotEntry,
                        screenshot: image,
                        spec: state.previewDevice,
                        config: state.buildConfig()
                    )
                    .scaleEffect(previewScale, anchor: .topLeading)
                    .frame(
                        width: state.previewDevice.canvasWidth * previewScale,
                        height: state.previewDevice.canvasHeight * previewScale
                    )
                    .padding(20)
                }
                .background(.black.opacity(0.05))
            } else if state.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Screenshots")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Click + to add a screenshot entry,\nthen choose an image file.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.05))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Image")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Choose an image for this screenshot\nin the inspector panel.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.05))
            }
        }
    }

    // Scale preview to fit nicely in the panel
    private var previewScale: CGFloat {
        0.55
    }
}
