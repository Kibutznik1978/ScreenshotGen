import SwiftUI

@main
struct ScreenshotGenApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("ScreenshotGen") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
