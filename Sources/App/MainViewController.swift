import AppKit

final class MainViewController: NSSplitViewController {

    let sidebarController  = SidebarController()
    let editorViewController = EditorViewController()

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
    }

    func setDirectory(_ url: URL) {
        sidebarController.setDirectory(url)
    }

    @objc private func handleNewNote() {
        sidebarController.createNoteInCurrentDirectory()
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
        editorViewController.load(url: url)
    }
}
