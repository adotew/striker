import SwiftUI

@main
struct LiquidGlassNoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
