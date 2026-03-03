import SwiftUI
import AppKit

public struct DeviceSpec: Sendable, Identifiable, Equatable {
    public let id: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let displaySize: String
    public let canvasWidth: CGFloat
    public let canvasHeight: CGFloat
    public let frameWidth: CGFloat
    public let frameAspectRatio: CGFloat
    public let outerCornerRadius: CGFloat
    public let innerCornerRadius: CGFloat
    public let bezelInset: CGFloat
    public let hasDynamicIsland: Bool
    public let deviceName: String
    public let renderScale: CGFloat

    public var label: String {
        "\(pixelWidth)x\(pixelHeight) — \(deviceName)"
    }

    // MARK: - iPhone Factory (3x rendering)

    public static func iPhone(pixelWidth: Int, pixelHeight: Int, displaySize: String, deviceName: String) -> DeviceSpec {
        let canvasW = CGFloat(pixelWidth) / 3
        let canvasH = CGFloat(pixelHeight) / 3
        let scale = canvasW / 430.0 // reference: iPhone 6.7" at 430pt wide

        return DeviceSpec(
            id: "iphone-\(pixelWidth)x\(pixelHeight)",
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            displaySize: displaySize,
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            frameWidth: round(340 * scale),
            frameAspectRatio: canvasH / canvasW,
            outerCornerRadius: round(50 * scale),
            innerCornerRadius: round(41 * scale),
            bezelInset: round(12 * scale),
            hasDynamicIsland: true,
            deviceName: deviceName,
            renderScale: 3.0
        )
    }

    // MARK: - iPad Factory (2x rendering)

    public static func iPad(pixelWidth: Int, pixelHeight: Int, displaySize: String, deviceName: String) -> DeviceSpec {
        let canvasW = CGFloat(pixelWidth) / 2
        let canvasH = CGFloat(pixelHeight) / 2
        let scale = canvasW / 1024.0 // reference: iPad 13" at 2048px / 2x

        return DeviceSpec(
            id: "ipad-\(pixelWidth)x\(pixelHeight)",
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            displaySize: displaySize,
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            frameWidth: round(760 * scale),
            frameAspectRatio: canvasH / canvasW,
            outerCornerRadius: round(46 * scale),
            innerCornerRadius: round(36 * scale),
            bezelInset: round(18 * scale),
            hasDynamicIsland: false,
            deviceName: deviceName,
            renderScale: 2.0
        )
    }

    // MARK: - iPhone 6.9" Display

    public static let iphone1320x2868 = iPhone(pixelWidth: 1320, pixelHeight: 2868, displaySize: "6.9", deviceName: "iPhone 16 Pro Max")
    public static let iphone1290x2796 = iPhone(pixelWidth: 1290, pixelHeight: 2796, displaySize: "6.9", deviceName: "iPhone 15 Pro Max")
    public static let iphone1260x2736 = iPhone(pixelWidth: 1260, pixelHeight: 2736, displaySize: "6.9", deviceName: "iPhone 16 Plus")

    // MARK: - iPhone 6.5" Display

    public static let iphone1284x2778 = iPhone(pixelWidth: 1284, pixelHeight: 2778, displaySize: "6.5", deviceName: "iPhone 15 Plus")
    public static let iphone1242x2688 = iPhone(pixelWidth: 1242, pixelHeight: 2688, displaySize: "6.5", deviceName: "iPhone 11 Pro Max")

    // MARK: - iPhone 6.3" Display

    public static let iphone1206x2622 = iPhone(pixelWidth: 1206, pixelHeight: 2622, displaySize: "6.3", deviceName: "iPhone 16 Pro")
    public static let iphone1179x2556 = iPhone(pixelWidth: 1179, pixelHeight: 2556, displaySize: "6.3", deviceName: "iPhone 15 Pro")

    // MARK: - iPhone 6.1" Display

    public static let iphone1170x2532 = iPhone(pixelWidth: 1170, pixelHeight: 2532, displaySize: "6.1", deviceName: "iPhone 14")
    public static let iphone1125x2436 = iPhone(pixelWidth: 1125, pixelHeight: 2436, displaySize: "6.1", deviceName: "iPhone 11 Pro")
    public static let iphone1080x2340 = iPhone(pixelWidth: 1080, pixelHeight: 2340, displaySize: "6.1", deviceName: "iPhone 12 mini")

    // MARK: - iPad 13" / 12.9" Display

    public static let ipad2064x2752 = iPad(pixelWidth: 2064, pixelHeight: 2752, displaySize: "13", deviceName: "iPad Pro M4/M5")
    public static let ipad2048x2732 = iPad(pixelWidth: 2048, pixelHeight: 2732, displaySize: "13", deviceName: "iPad Pro 12.9\"")

    // MARK: - iPad 11" Display

    public static let ipad1668x2420 = iPad(pixelWidth: 1668, pixelHeight: 2420, displaySize: "11", deviceName: "iPad Air M2")
    public static let ipad1668x2388 = iPad(pixelWidth: 1668, pixelHeight: 2388, displaySize: "11", deviceName: "iPad Pro 11\" 3rd gen")
    public static let ipad1640x2360 = iPad(pixelWidth: 1640, pixelHeight: 2360, displaySize: "11", deviceName: "iPad 10th gen")
    public static let ipad1488x2266 = iPad(pixelWidth: 1488, pixelHeight: 2266, displaySize: "11", deviceName: "iPad mini 6th gen")

    // MARK: - iPad 10.5" Display

    public static let ipad1668x2224 = iPad(pixelWidth: 1668, pixelHeight: 2224, displaySize: "10.5", deviceName: "iPad Pro 10.5\"")

    // MARK: - iPad 9.7" Display

    public static let ipad1536x2048 = iPad(pixelWidth: 1536, pixelHeight: 2048, displaySize: "9.7", deviceName: "iPad 6th gen")

    // MARK: - Catalog

    public static let allSpecs: [DeviceSpec] = [
        // iPhone
        .iphone1320x2868, .iphone1290x2796, .iphone1260x2736,
        .iphone1284x2778, .iphone1242x2688,
        .iphone1206x2622, .iphone1179x2556,
        .iphone1170x2532, .iphone1125x2436, .iphone1080x2340,
        // iPad
        .ipad2064x2752, .ipad2048x2732,
        .ipad1668x2420, .ipad1668x2388, .ipad1640x2360, .ipad1488x2266,
        .ipad1668x2224,
        .ipad1536x2048,
    ]

    public static func from(_ string: String) -> DeviceSpec? {
        allSpecs.first { $0.id == string }
    }
}

// MARK: - Display Categories (for UI grouping)

public struct DisplayCategory: Identifiable {
    public let id: String
    public let name: String
    public let devices: String
    public let specs: [DeviceSpec]

    public static let iPhoneCategories: [DisplayCategory] = [
        DisplayCategory(
            id: "iphone-6.9",
            name: "6.9\" Display",
            devices: "iPhone 16 Pro Max, 15 Pro Max, 16 Plus",
            specs: [.iphone1320x2868, .iphone1290x2796, .iphone1260x2736]
        ),
        DisplayCategory(
            id: "iphone-6.5",
            name: "6.5\" Display",
            devices: "iPhone 15 Plus, 14 Plus, 13 Pro Max, 11 Pro Max",
            specs: [.iphone1284x2778, .iphone1242x2688]
        ),
        DisplayCategory(
            id: "iphone-6.3",
            name: "6.3\" Display",
            devices: "iPhone 16 Pro, 15 Pro, 14 Pro",
            specs: [.iphone1206x2622, .iphone1179x2556]
        ),
        DisplayCategory(
            id: "iphone-6.1",
            name: "6.1\" Display",
            devices: "iPhone 15, 14, 13, 12, 11 Pro, XS",
            specs: [.iphone1170x2532, .iphone1125x2436, .iphone1080x2340]
        ),
    ]

    public static let iPadCategories: [DisplayCategory] = [
        DisplayCategory(
            id: "ipad-13",
            name: "13\" / 12.9\" Display",
            devices: "iPad Pro M4/M5, Air M3/M2, iPad Pro 12.9\" 1st–6th gen",
            specs: [.ipad2064x2752, .ipad2048x2732]
        ),
        DisplayCategory(
            id: "ipad-11",
            name: "11\" Display",
            devices: "iPad Pro 11\", Air, iPad 10th gen, mini 6th gen+",
            specs: [.ipad1668x2420, .ipad1668x2388, .ipad1640x2360, .ipad1488x2266]
        ),
        DisplayCategory(
            id: "ipad-10.5",
            name: "10.5\" Display",
            devices: "iPad Pro 10.5\", Air 3rd gen, iPad 9th–7th gen",
            specs: [.ipad1668x2224]
        ),
        DisplayCategory(
            id: "ipad-9.7",
            name: "9.7\" Display",
            devices: "iPad 6th–3rd gen, Air/Air 2, mini 2–5",
            specs: [.ipad1536x2048]
        ),
    ]

    public static let all: [DisplayCategory] = iPhoneCategories + iPadCategories
}

// MARK: - Device Frame View

public struct DeviceFrame: View {
    let screenshot: NSImage
    let spec: DeviceSpec

    public init(screenshot: NSImage, spec: DeviceSpec) {
        self.screenshot = screenshot
        self.spec = spec
    }

    private var frameHeight: CGFloat {
        spec.frameWidth * spec.frameAspectRatio
    }

    private var screenWidth: CGFloat {
        spec.frameWidth - spec.bezelInset * 2
    }

    private var screenHeight: CGFloat {
        frameHeight - spec.bezelInset * 2
    }

    public var body: some View {
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
                let scale = spec.canvasWidth / 430.0
                Capsule()
                    .fill(.black)
                    .frame(width: round(37 * scale), height: round(12 * scale))
                    .offset(y: -(frameHeight / 2 - round(30 * scale)))
            }
        }
        .frame(width: spec.frameWidth, height: frameHeight)
    }
}
