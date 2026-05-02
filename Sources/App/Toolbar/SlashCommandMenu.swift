import AppKit

// MARK: - Always-active row view (forces blue selection even in non-key window)

private final class ActiveRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set { }
    }
}

// MARK: - SlashCommandMenu

/// Vertical popup menu triggered by "/" in the editor.
/// Non-activating panel — never steals key focus from the text view.
final class SlashCommandMenu: NSPanel {

    var onSelect: ((Int) -> Void)?

    private var tableView: NSTableView!
    private var filteredIndices: [Int] = Array(0..<FormattingToolbar.actions.count)
    private var selectedRow: Int = 0

    // Display titles for the formatting actions (friendlier than raw "B", "H1", etc.)
    private static let displayTitles: [String] = [
        "Heading 1", "Heading 2", "Heading 3",
        "Bold", "Italic", "Strikethrough", "Code", "Link",
    ]

    var filterString: String = "" {
        didSet { updateFilter() }
    }

    var hasNoResults: Bool { filteredIndices.isEmpty }
    var visibleItemCount: Int { filteredIndices.count }
    var selectedItemIndex: Int { selectedRow }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 248),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        hasShadow = true
        backgroundColor = .clear
        setupContent()
    }

    override var canBecomeKey: Bool { false }

    // MARK: - Setup

    private func setupContent() {
        let vev = NSVisualEffectView()
        vev.material = .popover
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 8
        vev.layer?.masksToBounds = true
        contentView = vev

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        col.isEditable = false
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        vev.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: vev.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: vev.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: vev.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: vev.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Filter

    private func updateFilter() {
        if filterString.isEmpty {
            filteredIndices = Array(0..<FormattingToolbar.actions.count)
        } else {
            let lower = filterString.lowercased()
            filteredIndices = FormattingToolbar.actions.indices.filter { i in
                Self.displayTitles[i].lowercased().contains(lower)
            }
        }
        selectedRow = 0
        tableView.reloadData()
        if !filteredIndices.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        resizeToFitRows()
    }

    private func resizeToFitRows() {
        let rowCount = max(1, filteredIndices.count)
        let newHeight = CGFloat(rowCount) * tableView.rowHeight + 8
        var fr = frame
        fr.size.height = newHeight
        setFrame(fr, display: true)
    }

    // MARK: - Show / hide

    func show(caretRect: NSRect, in window: NSWindow) {
        filteredIndices = Array(0..<FormattingToolbar.actions.count)
        selectedRow = 0
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        let panelWidth: CGFloat = 200
        let panelHeight = CGFloat(filteredIndices.count) * tableView.rowHeight + 8

        // Position below the caret; flip upward if too close to bottom edge
        var x = caretRect.minX
        var y = caretRect.minY - panelHeight - 4

        if let screen = window.screen ?? NSScreen.main {
            let sf = screen.visibleFrame
            x = max(sf.minX + 4, min(x, sf.maxX - panelWidth - 4))
            if y < sf.minY {
                y = caretRect.maxY + 4
            }
        }

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: false)
        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
    }

    // MARK: - Keyboard navigation

    func moveUp() {
        guard !filteredIndices.isEmpty else { return }
        selectedRow = max(0, selectedRow - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedRow)
    }

    func moveDown() {
        guard !filteredIndices.isEmpty else { return }
        selectedRow = min(filteredIndices.count - 1, selectedRow + 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedRow)
    }

    func confirmSelection() {
        guard selectedRow < filteredIndices.count else { return }
        let originalIndex = filteredIndices[selectedRow]
        hide()
        onSelect?(originalIndex)
    }

    // MARK: - Click

    @objc private func rowClicked() {
        let clicked = tableView.clickedRow
        guard clicked >= 0 && clicked < filteredIndices.count else { return }
        selectedRow = clicked
        confirmSelection()
    }
}

// MARK: - NSTableViewDataSource

extension SlashCommandMenu: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredIndices.count
    }
}

// MARK: - NSTableViewDelegate

extension SlashCommandMenu: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ActiveRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredIndices.count else { return nil }
        let actionIndex = filteredIndices[row]
        let action = FormattingToolbar.actions[actionIndex]
        let displayTitle = Self.displayTitles[actionIndex]

        let cell = NSView()
        cell.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: action.symbol, accessibilityDescription: displayTitle) {
            imageView.image = img
        }
        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = .secondaryLabelColor

        let label = NSTextField(labelWithString: displayTitle)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor

        cell.addSubview(imageView)
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
        ])
        return cell
    }

}
