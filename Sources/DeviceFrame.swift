import SwiftUI
import AppKit

enum DeviceSpec: String, CaseIterable {
    case iPhone6_7 = "iphone-6.7"
    case iPad12_9 = "ipad-12.9"

    static func from(_ string: String) -> DeviceSpec? {
        DeviceSpec(rawValue: string)
    }

    // Canvas dimensions in points (rendered at 3x for final pixel size)
    var canvasWidth: CGFloat {
        switch self {
        case .iPhone6_7: return 430    // 1290 / 3
        case .iPad12_9: return 682.67  // 2048 / 3
        }
    }

    var canvasHeight: CGFloat {
        switch self {
        case .iPhone6_7: return 932    // 2796 / 3
        case .iPad12_9: return 910.67  // 2732 / 3
        }
    }

    var pixelWidth: Int {
        switch self {
        case .iPhone6_7: return 1290
        case .iPad12_9: return 2048
        }
    }

    var pixelHeight: Int {
        switch self {
        case .iPhone6_7: return 2796
        case .iPad12_9: return 2732
        }
    }

    // Device frame dimensions
    var frameWidth: CGFloat {
        switch self {
        case .iPhone6_7: return 340
        case .iPad12_9: return 520
        }
    }

    var frameAspectRatio: CGFloat {
        switch self {
        case .iPhone6_7: return 2.167  // 2796/1290
        case .iPad12_9: return 1.334   // 2732/2048
        }
    }

    var outerCornerRadius: CGFloat {
        switch self {
        case .iPhone6_7: return 50
        case .iPad12_9: return 36
        }
    }

    var innerCornerRadius: CGFloat {
        switch self {
        case .iPhone6_7: return 41
        case .iPad12_9: return 28
        }
    }

    var bezelInset: CGFloat {
        switch self {
        case .iPhone6_7: return 12
        case .iPad12_9: return 14
        }
    }

    var hasDynamicIsland: Bool {
        switch self {
        case .iPhone6_7: return true
        case .iPad12_9: return false
        }
    }

    var label: String {
        switch self {
        case .iPhone6_7: return "iPhone 6.7\""
        case .iPad12_9: return "iPad 12.9\""
        }
    }
}

struct DeviceFrame: View {
    let screenshot: NSImage
    let spec: DeviceSpec

    private var frameHeight: CGFloat {
        spec.frameWidth * spec.frameAspectRatio
    }

    private var screenWidth: CGFloat {
        spec.frameWidth - spec.bezelInset * 2
    }

    private var screenHeight: CGFloat {
        frameHeight - spec.bezelInset * 2
    }

    var body: some View {
        ZStack {
            // Outer device frame
            RoundedRectangle(cornerRadius: spec.outerCornerRadius)
                .fill(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)))
                .frame(width: spec.frameWidth, height: frameHeight)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            // Inner screen area with screenshot
            Image(nsImage: screenshot)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: spec.innerCornerRadius))

            // Dynamic Island (iPhone only)
            if spec.hasDynamicIsland {
                Capsule()
                    .fill(.black)
                    .frame(width: 37, height: 12)
                    .offset(y: -(frameHeight / 2 - 30))
            }
        }
        .frame(width: spec.frameWidth, height: frameHeight)
    }
}
