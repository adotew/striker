import AppKit

final class MainViewController: NSSplitViewController {

    let sidebarController = SidebarController()
    // Phase 3 will replace editorPlaceholder with EditorViewController
    private let editorPlaceholder = EditorPlaceholderViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 280
        addSplitViewItem(sidebarItem)

        let editorItem = NSSplitViewItem(viewController: editorPlaceholder)
        editorItem.minimumThickness = 240
        addSplitViewItem(editorItem)

        sidebarController.delegate = self
    }

    func setDirectory(_ url: URL) {
        sidebarController.setDirectory(url)
    }
}

// MARK: - SidebarControllerDelegate

extension MainViewController: SidebarControllerDelegate {

    func sidebarController(_ sidebar: SidebarController, shouldSelectFile url: URL) -> Bool {
        // Phase 3: check dirty state before switching
        return true
    }

    func sidebarController(_ sidebar: SidebarController, didSelectFile url: URL) {
        // Phase 3: load url in EditorViewController
        editorPlaceholder.showFile(url)
    }
}

// MARK: - Editor placeholder (replaced in Phase 3)

final class EditorPlaceholderViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let textView   = NSTextView()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
    }

    func showFile(_ url: URL) {
        let content = (try? FileManager.default.readNote(at: url)) ?? ""
        textView.string = content
        textView.scrollToBeginningOfDocument(nil)
    }
}
