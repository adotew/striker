import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingPanel: FloatingPanel!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // No Dock icon, no Cmd+Tab entry
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        floatingPanel = FloatingPanel()
        statusBarController = StatusBarController(panel: floatingPanel)
        hotkeyManager = HotkeyManager(panel: floatingPanel)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // TODO 3.2: autosave on quit
    }
}
