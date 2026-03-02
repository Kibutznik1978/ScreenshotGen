import SwiftUI
import Foundation

struct GeneratorConfig: Codable {
    let gradientTopColor: String
    let gradientBottomColor: String
    let textColor: String
    let supportTextOpacity: Double?
    let devices: [String]
    let screenshots: [ScreenshotEntry]

    var resolvedSupportTextOpacity: Double {
        supportTextOpacity ?? 0.8
    }

    var resolvedDevices: [DeviceSpec] {
        devices.compactMap { DeviceSpec.from($0) }
    }

    var gradientTop: Color {
        Color(hex: gradientTopColor)
    }

    var gradientBottom: Color {
        Color(hex: gradientBottomColor)
    }

    var text: Color {
        Color(hex: textColor)
    }
}

struct ScreenshotEntry: Codable {
    let id: String
    let rawImage: String
    let caption: String
    let supportText: String
}

// MARK: - Hex Color Parsing

extension Color {
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
}

// MARK: - Config Loading

func loadConfig(from url: URL) throws -> GeneratorConfig {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(GeneratorConfig.self, from: data)
}
