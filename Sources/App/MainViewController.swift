import AppKit

final class MainViewController: NSSplitViewController {

    let sidebarController  = SidebarController()
    let editorViewController = EditorViewController()
    private let fileWatcher = FileWatcher()
    private var isShowingExternalChangeAlert = false
    private(set) var currentDirectoryURL: URL?
    private let lastOpenFileBookmarkKey = "lastOpenFileBookmark"

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical  = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 280
        addSplitViewItem(sidebarItem)

        let editorItem = NSSplitViewItem(viewController: editorViewController)
        editorItem.minimumThickness = 240
        addSplitViewItem(editorItem)

        sidebarController.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewNote),
            name: .strikerNewNote,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidSaveFile(_:)),
            name: .strikerDidSaveFile,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleSidebar),
            name: .strikerToggleSidebar,
            object: nil
        )

        fileWatcher.onEvents = { [weak self] urls in
            self?.handleFileWatcherEvents(urls)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        fileWatcher.stop()
    }

    func setDirectory(_ url: URL) {
        currentDirectoryURL = url
        sidebarController.setDirectory(url)
        fileWatcher.startWatching(rootURL: url)
        restoreLastOpenFileIfPossible(in: url)
    }

    func toggleRawMode() {
        editorViewController.toggleRawMode()
    }

    var isRawMode: Bool {
        editorViewController.isRawMode
    }

    @objc private func handleToggleSidebar() {
        toggleSidebar(nil)
    }

    @objc private func handleNewNote() {
        sidebarController.createNoteInCurrentDirectory()
    }

    @objc private func handleDidSaveFile(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        fileWatcher.ignore(url: url)
    }

    private func handleFileWatcherEvents(_ urls: [URL]) {
        sidebarController.refresh()
        guard let currentURL = editorViewController.currentFileURL else { return }

        let currentPath = currentURL.standardizedFileURL.path
        let changedCurrentFile = urls.contains { $0.standardizedFileURL.path == currentPath }
        guard changedCurrentFile else { return }

        if editorViewController.isDirty {
            presentExternalChangeConflict(for: currentURL)
        } else {
            editorViewController.reloadCurrentFileFromDisk()
        }
    }

    private func presentExternalChangeConflict(for url: URL) {
        guard !isShowingExternalChangeAlert else { return }
        isShowingExternalChangeAlert = true

        let alert = NSAlert()
        alert.messageText = "File changed externally"
        alert.informativeText = "\"\(url.lastPathComponent)\" changed on disk. Reload or keep your version?"
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Keep My Version")
        alert.alertStyle = .warning

        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            self.isShowingExternalChangeAlert = false
            if response == .alertFirstButtonReturn {
                self.editorViewController.reloadCurrentFileFromDisk()
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            let response = alert.runModal()
            finish(response)
        }
    }

    private func storeLastOpenFile(_ url: URL) {
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return
        }
        UserDefaults.standard.set(data, forKey: lastOpenFileBookmarkKey)
    }

    private func restoreLastOpenFileIfPossible(in directory: URL) {
        guard let data = UserDefaults.standard.data(forKey: lastOpenFileBookmarkKey) else { return }
        var isStale = false
        guard let restoredURL = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            UserDefaults.standard.removeObject(forKey: lastOpenFileBookmarkKey)
            return
        }

        let target = restoredURL.standardizedFileURL
        let root = directory.standardizedFileURL
        let inRoot = target.path == root.path || target.path.hasPrefix(root.path + "/")
        guard inRoot, FileManager.default.fileExists(atPath: target.path) else {
            UserDefaults.standard.removeObject(forKey: lastOpenFileBookmarkKey)
            return
        }
        _ = sidebarController.selectFile(target)
    }
}

// MARK: - SidebarControllerDelegate

extension MainViewController: SidebarControllerDelegate {

    func sidebarController(_ sidebar: SidebarController, shouldSelectFile url: URL) -> Bool {
        // Save the current file before switching
        editorViewController.save()
        return true
    }

    func sidebarController(_ sidebar: SidebarController, didSelectFile url: URL) {
        storeLastOpenFile(url)
        editorViewController.load(url: url)
    }
}
