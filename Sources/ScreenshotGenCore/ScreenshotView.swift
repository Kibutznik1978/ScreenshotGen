import SwiftUI
import AppKit

public struct ScreenshotView: View {
    let entry: ScreenshotEntry
    let screenshot: NSImage
    let spec: DeviceSpec
    let config: GeneratorConfig

    public init(entry: ScreenshotEntry, screenshot: NSImage, spec: DeviceSpec, config: GeneratorConfig) {
        self.entry = entry
        self.screenshot = screenshot
        self.spec = spec
        self.config = config
    }

    /// Scale factor relative to the 430pt reference (iPhone 6.7" 1290px)
    private var scaleFactor: CGFloat {
        spec.canvasWidth / 430.0
    }

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [config.gradientTop, config.gradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                Spacer()
                    .frame(height: round(50 * scaleFactor))

                // Caption
                Text(entry.caption)
                    .font(.system(size: round(30 * scaleFactor), weight: .bold))
                    .foregroundStyle(config.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Support line
                Text(entry.supportText)
                    .font(.system(size: round(17 * scaleFactor), weight: .medium))
                    .foregroundStyle(config.text.opacity(config.resolvedSupportTextOpacity))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 16)

                // Device frame with screenshot
                DeviceFrame(screenshot: screenshot, spec: spec)

                Spacer()
                    .frame(height: round(20 * scaleFactor))
            }
        }
        .frame(width: spec.canvasWidth, height: spec.canvasHeight)
    }
}
