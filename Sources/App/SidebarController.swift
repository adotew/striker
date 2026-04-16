import AppKit

// MARK: - Delegate

protocol SidebarControllerDelegate: AnyObject {
    /// Called when the user selects a file. Return false to veto the switch (dirty check).
    func sidebarController(_ sidebar: SidebarController, shouldSelectFile url: URL) -> Bool
    func sidebarController(_ sidebar: SidebarController, didSelectFile url: URL)
}

// MARK: - SidebarController

final class SidebarController: NSViewController {

    weak var delegate: SidebarControllerDelegate?
    /// Called whenever the list of root folders changes (add/remove).
    var onRootsChanged: (() -> Void)?

    private let scrollView = NSScrollView()
    private let tableView  = NSTableView()

    private(set) var rootURLs: [URL] = []
    private var items: [SidebarItem] = []
    private var expandedURLs: Set<URL> = []
    private var collapsedRoots: Set<URL> = []
    private var hiddenFileURLs: Set<URL> = {
        let paths = UserDefaults.standard.stringArray(forKey: "hiddenFilePaths") ?? []
        return Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL })
    }()

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    private func setupTableView() {
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

        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: .init("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.sizeLastColumnToFit()

        scrollView.documentView = tableView

        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
    }

    // MARK: - Public API

    func setDirectory(_ url: URL) {
        setDirectories([url])
    }

    func setDirectories(_ urls: [URL]) {
        rootURLs = urls
        reload()
    }

    func addDirectory(_ url: URL) {
        let std = url.standardizedFileURL
        guard !rootURLs.contains(where: { $0.standardizedFileURL == std }) else { return }
        rootURLs.append(url)
        reload()
    }

    func removeDirectory(_ url: URL) {
        let std = url.standardizedFileURL
        rootURLs.removeAll { $0.standardizedFileURL == std }
        collapsedRoots.remove(url)
        reload()
    }

    func refresh() {
        reload()
    }

    @discardableResult
    func selectFile(_ url: URL) -> Bool {
        let target = url.standardizedFileURL
        guard let root = rootURLs.first(where: {
            let r = $0.standardizedFileURL
            return target.path == r.path || target.path.hasPrefix(r.path + "/")
        }) else { return false }

        // Ensure root is not collapsed
        collapsedRoots.remove(root)

        // Expand ancestor directories up to root
        var parent = target.deletingLastPathComponent()
        let standardRoot = root.standardizedFileURL
        while parent != standardRoot && parent.path.hasPrefix(standardRoot.path) {
            expandedURLs.insert(parent)
            parent = parent.deletingLastPathComponent()
        }

        reload()
        guard let row = items.firstIndex(where: { $0.url.standardizedFileURL == target }) else {
            return false
        }
        tableView.scrollRowToVisible(row)
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return true
    }

    /// Creates a new note in the directory of the currently selected item (or first root).
    func createNoteInCurrentDirectory() {
        let targetDir: URL
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            let item = items[selectedRow]
            if item.isRootHeader {
                targetDir = item.url
            } else {
                targetDir = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
            }
        } else {
            targetDir = rootURLs.first ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        guard let newURL = try? FileManager.default.createNote(in: targetDir) else { return }
        reload()
        select(url: newURL)
        promptRename(url: newURL)
    }

    // MARK: - Internal

    private func reload() {
        items = []
        let showHeaders = rootURLs.count > 1

        for root in rootURLs {
            if showHeaders {
                let isExpanded = !collapsedRoots.contains(root)
                items.append(SidebarItem.rootHeader(url: root, isExpanded: isExpanded))
                if isExpanded {
                    items += SidebarItem.loadDirectory(
                        url: root,
                        depth: 1,
                        expandedURLs: expandedURLs,
                        rootURL: root,
                        hiddenURLs: hiddenFileURLs
                    )
                }
            } else {
                items += SidebarItem.loadDirectory(
                    url: root,
                    depth: 0,
                    expandedURLs: expandedURLs,
                    rootURL: root,
                    hiddenURLs: hiddenFileURLs
                )
            }
        }
        tableView.reloadData()
    }

    private func toggleExpand(at row: Int) {
        let item = items[row]
        if expandedURLs.contains(item.url) {
            expandedURLs.remove(item.url)
        } else {
            expandedURLs.insert(item.url)
        }
        reload()
    }

    private func select(url: URL) {
        guard let row = items.firstIndex(where: { $0.url == url }) else { return }
        tableView.scrollRowToVisible(row)
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    // MARK: - Rename alert

    private func promptRename(url: URL) {
        guard let window = view.window else { return }

        let isDir = url.hasDirectoryPath
        let currentName: String
        if isDir {
            currentName = url.lastPathComponent
        } else {
            let base = url.lastPathComponent
            currentName = base.hasSuffix(".md") ? String(base.dropLast(3)) : base
        }

        let alert = NSAlert()
        alert.messageText = "Rename \(isDir ? "Folder" : "Note")"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        tf.stringValue = currentName
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = tf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !newName.isEmpty else { return }
            if let newURL = try? FileManager.default.renameNote(at: url, to: newName) {
                self?.reload()
                self?.select(url: newURL)
            }
        }
    }
}

// MARK: - NSTableViewDataSource

extension SidebarController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
}

// MARK: - NSTableViewDelegate

extension SidebarController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let id = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? SidebarCellView)
                   ?? SidebarCellView(identifier: id)
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        items[row].isRootHeader ? 24 : 28
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let item = items[row]

        if item.isRootHeader {
            if collapsedRoots.contains(item.url) {
                collapsedRoots.remove(item.url)
            } else {
                collapsedRoots.insert(item.url)
            }
            tableView.deselectRow(row)
            reload()
            return
        }

        if item.isDirectory {
            toggleExpand(at: row)
            tableView.deselectRow(row)
            return
        }

        if delegate?.sidebarController(self, shouldSelectFile: item.url) == false {
            tableView.deselectRow(row)
            return
        }
        delegate?.sidebarController(self, didSelectFile: item.url)
    }
}

// MARK: - NSMenuDelegate (context menu)

extension SidebarController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let clickedRow = tableView.clickedRow

        if clickedRow >= 0 {
            let item = items[clickedRow]

            if item.isRootHeader {
                addMenuItem(to: menu, title: "New Note",      action: #selector(menuNewNote(_:)),      object: item.url)
                addMenuItem(to: menu, title: "New Folder",    action: #selector(menuNewFolder(_:)),    object: item.url)
                menu.addItem(.separator())
                addMenuItem(to: menu, title: "Remove Folder", action: #selector(menuRemoveRoot(_:)),   object: item.url)
                return
            }

            let targetDir = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
            addMenuItem(to: menu, title: "New Note",   action: #selector(menuNewNote(_:)),   object: targetDir)
            addMenuItem(to: menu, title: "New Folder", action: #selector(menuNewFolder(_:)), object: targetDir)
            menu.addItem(.separator())
            addMenuItem(to: menu, title: "Rename", action: #selector(menuRename(_:)), object: item.url)
            if !item.isDirectory {
                addMenuItem(to: menu, title: "Remove", action: #selector(menuRemoveFile(_:)), object: item.url)
            }
            addMenuItem(to: menu, title: "Delete", action: #selector(menuDelete(_:)), object: item.url)

        } else {
            addMenuItem(to: menu, title: "Add Folder", action: #selector(menuAddFolder(_:)), object: nil)
        }
    }

    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, object: Any?) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = object
        menu.addItem(item)
    }

    @objc private func menuNewNote(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? URL,
              let newURL = try? FileManager.default.createNote(in: dir) else { return }
        reload()
        select(url: newURL)
        promptRename(url: newURL)
    }

    @objc private func menuNewFolder(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? URL,
              let newURL = try? FileManager.default.createFolder(in: dir) else { return }
        reload()
        select(url: newURL)
        promptRename(url: newURL)
    }

    @objc private func menuRename(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        promptRename(url: url)
    }

    @objc private func menuDelete(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let name = url.lastPathComponent
        let alert = NSAlert()
        alert.messageText = "Move \"\(name)\" to Trash?"
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            try? FileManager.default.deleteNote(at: url)
            self?.reload()
        }
    }

    @objc private func menuRemoveFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        hiddenFileURLs.insert(url.standardizedFileURL)
        UserDefaults.standard.set(hiddenFileURLs.map(\.path), forKey: "hiddenFilePaths")
        reload()
    }

    @objc private func menuRemoveRoot(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        removeDirectory(url)
        onRootsChanged?()
    }

    @objc private func menuAddFolder(_ sender: NSMenuItem) {
        DirectoryPicker.pick { [weak self] url in
            guard let self, let url else { return }
            self.addDirectory(url)
            self.onRootsChanged?()
        }
    }
}

// MARK: - SidebarCellView

final class SidebarCellView: NSTableCellView {

    private let iconView  = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var indentConstraint: NSLayoutConstraint!

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.cell?.wraps = false
        addSubview(nameLabel)

        indentConstraint = iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)

        NSLayoutConstraint.activate([
            indentConstraint,
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with item: SidebarItem) {
        if item.isRootHeader {
            indentConstraint.constant = 8
            let chevron = item.isExpanded ? "chevron.down" : "chevron.right"
            iconView.image = NSImage(systemSymbolName: chevron, accessibilityDescription: nil)
            iconView.contentTintColor = .secondaryLabelColor
            nameLabel.stringValue = item.name.uppercased()
            nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
            nameLabel.textColor = .secondaryLabelColor
            return
        }

        indentConstraint.constant = CGFloat(item.depth) * 16 + 8
        iconView.contentTintColor = nil

        if item.isDirectory {
            let symbolName = item.isExpanded ? "folder.fill" : "folder"
            iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            nameLabel.stringValue = item.name
        } else {
            iconView.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            let base = item.name
            nameLabel.stringValue = base.hasSuffix(".md") ? String(base.dropLast(3)) : base
        }
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
    }
}
