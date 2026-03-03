import SwiftUI
import AppKit
import ScreenshotGenCore

@main
struct ScreenshotGenUIApp: App {
    @State private var state = ProjectState()

    init() {
        // When running as a bare executable (not a .app bundle),
        // macOS won't activate the app automatically — keyboard input won't work.
        // In a proper .app bundle this is handled automatically.
        if !Bundle.main.bundlePath.hasSuffix(".app") {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

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
