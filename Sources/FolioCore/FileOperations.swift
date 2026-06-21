import Foundation

/// File system actions invoked from the UI, kept here so they can be tested directly.
public enum FileOperations {
    public enum OperationError: Error, Equatable {
        case emptyName
        case invalidName
        case sameLocation
        case invalidDestination
    }

    /// Move a file or folder to the Trash (recoverable). Returns the item's new URL in the
    /// Trash on success. Throws if the item doesn't exist or can't be moved.
    @discardableResult
    public static func moveToTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }

    /// Rename `url` to `newName` within the same directory. Returns the new URL.
    /// The new name is trimmed; blank names and names containing a path separator are rejected.
    @discardableResult
    public static func rename(_ url: URL, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OperationError.emptyName }
        guard !trimmed.contains("/") else { throw OperationError.invalidName }

        let destination = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    /// Move a file or folder `url` into `directory`. Returns the item's new URL.
    /// Rejects a move into the item's current parent (no-op) or, for a folder, into itself
    /// or one of its own descendants.
    @discardableResult
    public static func move(_ url: URL, into directory: URL) throws -> URL {
        let src = url.standardizedFileURL
        let dir = directory.standardizedFileURL

        if src.deletingLastPathComponent().path == dir.path { throw OperationError.sameLocation }

        // Disallow moving a folder into itself or a descendant of itself.
        let srcPrefix = src.path.hasSuffix("/") ? src.path : src.path + "/"
        if dir.path == src.path || dir.path.hasPrefix(srcPrefix) {
            throw OperationError.invalidDestination
        }

        let destination = dir.appendingPathComponent(src.lastPathComponent)
        try FileManager.default.moveItem(at: src, to: destination)
        return destination
    }
}
