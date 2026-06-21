import Foundation

/// Bounds for tree loading, to keep very large folders from hanging or exhausting memory.
public struct LoadLimits: Sendable {
    public var maxEntries: Int
    public var maxDepth: Int
    public init(maxEntries: Int = 1_000_000, maxDepth: Int = 32) {
        self.maxEntries = maxEntries
        self.maxDepth = maxDepth
    }
    public static let `default` = LoadLimits()
}

/// Result of a bounded load: the tree plus whether limits cut it short.
public struct LoadResult: Sendable {
    public let root: FileNode
    public let truncated: Bool
}

/// Builds a `FileNode` tree from a directory on disk.
/// Hidden entries (dotfiles) are skipped; directories sort before files,
/// and within each group entries sort case-insensitively A–Z.
public enum FileTreeLoader {
    /// Load the whole tree at `url` (uses default limits). Convenience that returns just the root.
    public static func load(_ url: URL) -> FileNode {
        load(url, limits: .default).root
    }

    /// Load the tree at `url`, stopping when `limits` are exceeded.
    /// - Parameter includeHidden: when true, dotfiles/dot-folders are included.
    public static func load(_ url: URL, limits: LoadLimits, includeHidden: Bool = false) -> LoadResult {
        let budget = Budget(remaining: limits.maxEntries)
        let root = node(at: url, depth: 0, limits: limits, includeHidden: includeHidden, budget: budget)
        return LoadResult(root: root, truncated: budget.truncated)
    }

    // MARK: - Private

    private final class Budget {
        var remaining: Int
        var truncated = false
        init(remaining: Int) { self.remaining = remaining }
    }

    private static func node(at url: URL, depth: Int, limits: LoadLimits, includeHidden: Bool, budget: Budget) -> FileNode {
        guard isDirectory(url) else { return FileNode(url: url, isDirectory: false, children: nil) }

        if depth >= limits.maxDepth {
            budget.truncated = true
            return FileNode(url: url, isDirectory: true, children: [])
        }

        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        let entries = (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        )) ?? []

        let sorted = entries.sorted(by: orderedURLs)
        var children: [FileNode] = []
        for entry in sorted {
            if budget.remaining <= 0 { budget.truncated = true; break }
            budget.remaining -= 1
            children.append(node(at: entry, depth: depth + 1, limits: limits, includeHidden: includeHidden, budget: budget))
        }
        return FileNode(url: url, isDirectory: true, children: children)
    }

    /// Directories first, then case-insensitive name order (operates on raw URLs).
    private static func orderedURLs(_ a: URL, _ b: URL) -> Bool {
        let da = isDirectory(a), db = isDirectory(b)
        if da != db { return da }
        return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
