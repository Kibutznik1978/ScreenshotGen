import SwiftUI
import Foundation

public struct GeneratorConfig: Codable {
    public var gradientTopColor: String
    public var gradientBottomColor: String
    public var textColor: String
    public var supportTextOpacity: Double?
    public var devices: [String]
    public var screenshots: [ScreenshotEntry]

    public var resolvedSupportTextOpacity: Double {
        supportTextOpacity ?? 0.8
    }

    public var resolvedDevices: [DeviceSpec] {
        devices.compactMap { DeviceSpec.from($0) }
    }

    public var gradientTop: Color {
        Color(hex: gradientTopColor)
    }

    public var gradientBottom: Color {
        Color(hex: gradientBottomColor)
    }

    public var text: Color {
        Color(hex: textColor)
    }

    public init(
        gradientTopColor: String = "#337AF5",
        gradientBottomColor: String = "#245CCC",
        textColor: String = "#FFFFFF",
        supportTextOpacity: Double? = 0.8,
        devices: [String] = ["iphone-6.7", "ipad-12.9"],
        screenshots: [ScreenshotEntry] = []
    ) {
        self.gradientTopColor = gradientTopColor
        self.gradientBottomColor = gradientBottomColor
        self.textColor = textColor
        self.supportTextOpacity = supportTextOpacity
        self.devices = devices
        self.screenshots = screenshots
    }
}

public struct ScreenshotEntry: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var rawImage: String
    public var caption: String
    public var supportText: String

    public init(id: String, rawImage: String, caption: String, supportText: String) {
        self.id = id
        self.rawImage = rawImage
        self.caption = caption
        self.supportText = supportText
    }
}

// MARK: - Hex Color Parsing

public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Config Loading & Saving

public func loadConfig(from url: URL) throws -> GeneratorConfig {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(GeneratorConfig.self, from: data)
}

public func saveConfig(_ config: GeneratorConfig, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: url, options: .atomic)
}
