import Foundation

struct SidebarItem {
    enum Kind {
        case normal
        case rootHeader
        case emptyFolderHint(parent: URL)
    }

    let url: URL
    let name: String
    let isDirectory: Bool
    let depth: Int
    var isExpanded: Bool
    var kind: Kind = .normal
    var rootURL: URL? = nil

    var isRootHeader: Bool {
        if case .rootHeader = kind { return true }
        return false
    }

    var emptyFolderParentURL: URL? {
        if case let .emptyFolderHint(parent) = kind { return parent }
        return nil
    }

    var isEmptyFolderHint: Bool {
        emptyFolderParentURL != nil
    }

    /// Synthetic root header row — not a real filesystem item.
    static func rootHeader(url: URL, isExpanded: Bool) -> SidebarItem {
        SidebarItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: true,
            depth: 0,
            isExpanded: isExpanded,
            kind: .rootHeader,
            rootURL: url
        )
    }

    /// Synthetic empty-hint row for an expanded folder that has no visible children.
    static func emptyFolderHint(parentURL: URL, depth: Int, rootURL: URL?) -> SidebarItem {
        SidebarItem(
            url: parentURL,
            name: "New Note",
            isDirectory: false,
            depth: depth,
            isExpanded: false,
            kind: .emptyFolderHint(parent: parentURL),
            rootURL: rootURL
        )
    }

    /// Returns a flat array representing the visible tree for `url`.
    /// Folders come before files (both alphabetical). Expanded folders
    /// inline their children recursively.
    static func loadDirectory(
        url: URL,
        depth: Int = 0,
        expandedURLs: Set<URL> = [],
        rootURL: URL? = nil,
        hiddenURLs: Set<URL> = []
    ) -> [SidebarItem] {
        let effectiveRoot = rootURL ?? url

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        let filtered = entries.filter { entry in
            guard !hiddenURLs.contains(entry.standardizedFileURL) else { return false }
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            return isDir || entry.pathExtension.lowercased() == "md"
        }

        let sorted = filtered.sorted { a, b in
            let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            if aIsDir != bIsDir { return aIsDir }
            return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }

        var result: [SidebarItem] = []
        for entry in sorted {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let expanded = isDir && expandedURLs.contains(entry)
            result.append(SidebarItem(
                url: entry,
                name: entry.lastPathComponent,
                isDirectory: isDir,
                depth: depth,
                isExpanded: expanded,
                kind: .normal,
                rootURL: effectiveRoot
            ))
            if expanded {
                let children = loadDirectory(
                    url: entry,
                    depth: depth + 1,
                    expandedURLs: expandedURLs,
                    rootURL: effectiveRoot,
                    hiddenURLs: hiddenURLs
                )
                if children.isEmpty {
                    result.append(.emptyFolderHint(parentURL: entry, depth: depth + 1, rootURL: effectiveRoot))
                } else {
                    result += children
                }
            }
        }
        return result
    }
}
