import Foundation
import ScreenshotGenCore

struct Project: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var config: GeneratorConfig

    static func defaultProject() -> Project {
        Project(
            id: UUID(),
            name: "My App",
            createdAt: Date(),
            config: GeneratorConfig(
                gradientTopColor: "#337AF5",
                gradientBottomColor: "#245CCC",
                textColor: "#FFFFFF",
                supportTextOpacity: 0.8,
                devices: [
                    "iphone-1290x2796",
                    "iphone-1284x2778",
                    "iphone-1179x2556",
                    "iphone-1170x2532"
                ],
                screenshots: [
                    ScreenshotEntry(id: "01", rawImage: "01-screenshot.png",
                                    caption: "Your headline\ngoes here",
                                    supportText: "A subtitle explaining the feature"),
                    ScreenshotEntry(id: "02", rawImage: "02-screenshot.png",
                                    caption: "Another great\nfeature",
                                    supportText: "Describe what makes it special"),
                    ScreenshotEntry(id: "03", rawImage: "03-screenshot.png",
                                    caption: "One more thing\nto show",
                                    supportText: "The finishing touch"),
                ]
            )
        )
    }
}
