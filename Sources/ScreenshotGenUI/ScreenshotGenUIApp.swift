import SwiftUI
import ScreenshotGenCore

@main
struct ScreenshotGenUIApp: App {
    @State private var state = ProjectState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    state.loadIfNeeded()
                }
        }
        .windowResizability(.contentMinSize)
    }
}
