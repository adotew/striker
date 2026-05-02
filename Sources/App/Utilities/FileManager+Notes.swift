import AppKit

extension FileManager {

    func createNote(in directory: URL, name: String = "Untitled") throws -> URL {
        var candidate = name.hasSuffix(".md") ? name : "\(name).md"
        var url = directory.appendingPathComponent(candidate)
        var counter = 2
        while fileExists(atPath: url.path) {
            candidate = "\(name) \(counter).md"
            url = directory.appendingPathComponent(candidate)
            counter += 1
        }
        guard createFile(atPath: url.path, contents: Data()) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    func createFolder(in directory: URL, name: String = "New Folder") throws -> URL {
        var url = directory.appendingPathComponent(name, isDirectory: true)
        var counter = 2
        while fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(name) \(counter)", isDirectory: true)
            counter += 1
        }
        try createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func deleteNote(at url: URL) throws {
        try trashItem(at: url, resultingItemURL: nil)
    }

    /// Renames a file or folder. For .md files the extension is preserved
    /// unless `newName` explicitly includes a different one.
    func renameNote(at url: URL, to newName: String) throws -> URL {
        var targetName = newName
        if !url.hasDirectoryPath && url.pathExtension == "md" && !newName.contains(".") {
            targetName = "\(newName).md"
        }
        let destination = url.deletingLastPathComponent().appendingPathComponent(targetName)
        try moveItem(at: url, to: destination)
        return destination
    }

    func readNote(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func writeNote(at url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
