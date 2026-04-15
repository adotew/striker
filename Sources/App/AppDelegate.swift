import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var floatingPanel: FloatingPanel!
    private var mainViewController: MainViewController!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // No Dock icon, no Cmd+Tab entry
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        floatingPanel = FloatingPanel()

        mainViewController = MainViewController()
        floatingPanel.setMainContent(viewController: mainViewController)

        statusBarController = StatusBarController(panel: floatingPanel)
        hotkeyManager = HotkeyManager(panel: floatingPanel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hidePanel),
            name: .strikerHidePanel,
            object: nil
        )

        if let url = DirectoryPicker.resolveBookmark() {
            mainViewController.setDirectory(url)
        } else {
            floatingPanel.toggle()
            DirectoryPicker.pick { [weak self] url in
                guard let url else { return }
                self?.mainViewController.setDirectory(url)
            }
            return
        }
        floatingPanel.toggle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainViewController.editorViewController.save()
    }

    @objc private func hidePanel() {
        floatingPanel.toggle()
    }
}
