import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingPanel: FloatingPanel!
    private var mainViewController: MainViewController!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var preferencesWindowController: PreferencesWindowController!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // No Dock icon, no Cmd+Tab entry
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        floatingPanel = FloatingPanel()

        mainViewController = MainViewController()
        floatingPanel.setMainContent(viewController: mainViewController)

        preferencesWindowController = PreferencesWindowController(
            directoryProvider: { [weak self] in self?.mainViewController.currentDirectoryURL },
            onDirectoryChanged: { [weak self] url in self?.setNotesDirectory(url) },
            isAlwaysOnTop: { [weak self] in self?.floatingPanel.isAlwaysOnTop ?? true },
            setAlwaysOnTop: { [weak self] isEnabled in self?.floatingPanel.isAlwaysOnTop = isEnabled }
        )

        statusBarController = StatusBarController(
            panel: floatingPanel,
            onOpenPreferences: { [weak self] in self?.showPreferences() },
            onToggleRawMode: { [weak self] in self?.mainViewController.toggleRawMode() },
            isRawModeEnabled: { [weak self] in self?.mainViewController.isRawMode ?? false },
            onToggleSidebar: { [weak self] in self?.mainViewController.toggleSidebar(nil) }
        )
        hotkeyManager = HotkeyManager(panel: floatingPanel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hidePanel),
            name: .strikerHidePanel,
            object: nil
        )

        let hadBookmarks = UserDefaults.standard.data(forKey: "notesDirectoryBookmark") != nil
                        || (UserDefaults.standard.array(forKey: "notesDirectoryBookmarks") as? [Data])?.isEmpty == false
        DirectoryPicker.migrateLegacyBookmarkIfNeeded()
        let restoredURLs = DirectoryPicker.resolveAllBookmarks().filter { isValidNotesDirectory($0) }
        if !restoredURLs.isEmpty {
            mainViewController.setDirectories(restoredURLs)
            floatingPanel.toggle()
            return
        }
        if hadBookmarks {
            showDirectoryUnavailableAlert()
        }
        floatingPanel.toggle()
        promptForNotesDirectory()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainViewController.editorViewController.save()
    }

    @objc private func hidePanel() {
        floatingPanel.toggle()
    }

    private func showPreferences() {
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    private func setNotesDirectory(_ url: URL) -> Bool {
        guard isValidNotesDirectory(url) else { return false }
        DirectoryPicker.appendBookmark(for: url)
        mainViewController.setDirectory(url)
        return true
    }

    private func isValidNotesDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func promptForNotesDirectory() {
        DirectoryPicker.pick { [weak self] url in
            guard let self, let url else { return }
            guard self.isValidNotesDirectory(url) else {
                self.showDirectoryUnavailableAlert()
                self.promptForNotesDirectory()
                return
            }
            DirectoryPicker.appendBookmark(for: url)
            self.mainViewController.setDirectory(url)
        }
    }

    private func showDirectoryUnavailableAlert() {
        let alert = NSAlert()
        alert.messageText = "Notes directory unavailable"
        alert.informativeText = "The previously selected notes directory is missing or inaccessible. Please choose a new directory."
        alert.alertStyle = .warning
        alert.runModal()
    }
}
