import AppKit

final class StatusBarController {

    private let statusItem: NSStatusItem
    private let panel: FloatingPanel

    init(panel: FloatingPanel) {
        self.panel = panel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Striker")
        button.image?.isTemplate = true
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu(from: sender)
        } else {
            panel.toggle()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Striker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // clear so left-click still works via action
    }

    @objc private func toggleAlwaysOnTop() {
        panel.isAlwaysOnTop.toggle()
    }
}
