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
                    .frame(height: topSpacing)

                // Caption
                Text(entry.caption)
                    .font(.system(size: captionFontSize, weight: .bold))
                    .foregroundStyle(config.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Support line
                Text(entry.supportText)
                    .font(.system(size: supportFontSize, weight: .medium))
                    .foregroundStyle(config.text.opacity(config.resolvedSupportTextOpacity))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 16)

                // Device frame with screenshot
                DeviceFrame(screenshot: screenshot, spec: spec)

                Spacer()
                    .frame(height: bottomSpacing)
            }
        }
        .frame(width: spec.canvasWidth, height: spec.canvasHeight)
    }

    // Scale text and spacing based on device
    private var captionFontSize: CGFloat {
        switch spec {
        case .iPhone6_7: return 30
        case .iPad12_9: return 38
        }
    }

    private var supportFontSize: CGFloat {
        switch spec {
        case .iPhone6_7: return 17
        case .iPad12_9: return 22
        }
    }

    private var topSpacing: CGFloat {
        switch spec {
        case .iPhone6_7: return 50
        case .iPad12_9: return 40
        }
    }

    private var bottomSpacing: CGFloat {
        switch spec {
        case .iPhone6_7: return 20
        case .iPad12_9: return 20
        }
    }
}
