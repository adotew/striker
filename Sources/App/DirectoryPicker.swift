import AppKit

enum DirectoryPicker {

    private static let bookmarkKey = "notesDirectoryBookmark"

    /// Resolves the stored bookmark. Returns nil if none stored or bookmark is stale.
    static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }
        return url
    }

    /// Presents NSOpenPanel. On selection, stores a bookmark and calls completion on main queue.
    static func pick(completion: @escaping (URL?) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.message = "Choose your notes directory"
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            completion(nil)
            return
        }
        storeBookmark(for: url)
        completion(url)
    }

    private static func storeBookmark(for url: URL) {
        let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }
}
