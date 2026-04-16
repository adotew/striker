import Foundation

struct SidebarItem {
    let url: URL
    let name: String
    let isDirectory: Bool
    let depth: Int
    var isExpanded: Bool
    var isRootHeader: Bool = false
    var rootURL: URL? = nil

    /// Synthetic root header row — not a real filesystem item.
    static func rootHeader(url: URL, isExpanded: Bool) -> SidebarItem {
        SidebarItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: true,
            depth: 0,
            isExpanded: isExpanded,
            isRootHeader: true,
            rootURL: url
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
                isRootHeader: false,
                rootURL: effectiveRoot
            ))
            if expanded {
                result += loadDirectory(url: entry, depth: depth + 1, expandedURLs: expandedURLs, rootURL: effectiveRoot, hiddenURLs: hiddenURLs)
            }
        }
        return result
    }
}
