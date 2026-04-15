import AppKit

final class StatusBarController {

    private let statusItem: NSStatusItem
    private let panel: FloatingPanel
    private let onOpenPreferences: () -> Void
    private let onToggleRawMode: () -> Void
    private let isRawModeEnabled: () -> Bool

    init(
        panel: FloatingPanel,
        onOpenPreferences: @escaping () -> Void,
        onToggleRawMode: @escaping () -> Void,
        isRawModeEnabled: @escaping () -> Bool
    ) {
        self.panel = panel
        self.onOpenPreferences = onOpenPreferences
        self.onToggleRawMode = onToggleRawMode
        self.isRawModeEnabled = isRawModeEnabled
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Striker")
        button.image?.isTemplate = true
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePanelVisibilityChange),
            name: NSWindow.didBecomeKeyNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePanelVisibilityChange),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
        updateStatusHighlight()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu(from: sender)
        } else {
            panel.toggle()
            updateStatusHighlight()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let alwaysOnTopItem = menu.addItem(withTitle: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        alwaysOnTopItem.state = panel.isAlwaysOnTop ? .on : .off

        let rawModeItem = menu.addItem(withTitle: "Raw Markdown Mode", action: #selector(toggleRawMode), keyEquivalent: "")
        rawModeItem.target = self
        rawModeItem.state = isRawModeEnabled() ? .on : .off

        menu.addItem(.separator())

        let preferencesItem = menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self

        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit Striker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // clear so left-click still works via action
    }

    @objc private func toggleAlwaysOnTop() {
        panel.isAlwaysOnTop.toggle()
        updateStatusHighlight()
    }

    @objc private func toggleRawMode() {
        onToggleRawMode()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func handlePanelVisibilityChange() {
        updateStatusHighlight()
    }

    private func updateStatusHighlight() {
        statusItem.button?.contentTintColor = panel.isVisible ? NSColor.controlAccentColor : nil
    }
}
