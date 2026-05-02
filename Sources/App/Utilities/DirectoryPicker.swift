import AppKit

enum DirectoryPicker {

    private static let bookmarksKey = "notesDirectoryBookmarks"
    private static let legacyBookmarkKey = "notesDirectoryBookmark"

    // MARK: - Multi-bookmark API

    /// Resolves all stored root-folder bookmarks. Prunes stale entries in place.
    static func resolveAllBookmarks() -> [URL] {
        guard let dataArray = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return []
        }
        var valid: [(Data, URL)] = []
        for data in dataArray {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale else { continue }
            valid.append((data, url))
        }
        // Write back pruned list
        UserDefaults.standard.set(valid.map(\.0), forKey: bookmarksKey)
        return valid.map(\.1)
    }

    /// Replaces the stored list with bookmarks for the given URLs.
    static func storeAllBookmarks(urls: [URL]) {
        let dataArray = urls.compactMap { url in
            try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(dataArray, forKey: bookmarksKey)
    }

    /// Appends a bookmark for `url` if not already present.
    static func appendBookmark(for url: URL) {
        var current = resolveAllBookmarks()
        let std = url.standardizedFileURL
        guard !current.contains(where: { $0.standardizedFileURL == std }) else { return }
        current.append(url)
        storeAllBookmarks(urls: current)
    }

    /// Removes the bookmark matching `url`.
    static func removeBookmark(for url: URL) {
        let std = url.standardizedFileURL
        let current = resolveAllBookmarks().filter { $0.standardizedFileURL != std }
        storeAllBookmarks(urls: current)
    }

    /// One-time migration: reads the legacy single-bookmark key and prepends it to the
    /// new array, then deletes the legacy key.
    static func migrateLegacyBookmarkIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: legacyBookmarkKey) else { return }
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale {
            var current = resolveAllBookmarks()
            let std = url.standardizedFileURL
            if !current.contains(where: { $0.standardizedFileURL == std }) {
                current.insert(url, at: 0)
                storeAllBookmarks(urls: current)
            }
        }
        UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
    }

    // MARK: - Legacy single-bookmark (kept for migration shim only)

    static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: legacyBookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
            return nil
        }
        return url
    }

    // MARK: - Picker

    /// Presents NSOpenPanel. Calls completion with the chosen URL (or nil on cancel).
    /// The caller decides whether to append or replace bookmarks.
    static func pick(completion: @escaping (URL?) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.message = "Choose a notes directory"
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            completion(nil)
            return
        }
        completion(url)
    }
}
