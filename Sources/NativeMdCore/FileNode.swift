import Foundation

/// A node in the file tree shown in the sidebar.
/// `children` is `nil` for files and a (possibly empty) array for directories,
/// which is exactly what SwiftUI's `OutlineGroup` expects.
public struct FileNode: Identifiable, Hashable, Sendable {
    public let url: URL
    public let isDirectory: Bool
    public var children: [FileNode]?

    public init(url: URL, isDirectory: Bool, children: [FileNode]?) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    /// True for dotfiles/dot-folders (hidden entries), e.g. `.git`, `.env`.
    public var isHidden: Bool { name.hasPrefix(".") }

    // Identity is the URL; avoid hashing/comparing the whole subtree.
    public static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.url == rhs.url }
    public func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

public extension FileNode {
    /// All file (leaf) descendants whose name contains `query` (case-insensitive),
    /// in pre-order. An empty/whitespace query returns every file. Directories are excluded.
    func matchingFiles(query: String) -> [FileNode] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result: [FileNode] = []
        collectFiles(matching: q, into: &result)
        return result
    }

    private func collectFiles(matching q: String, into result: inout [FileNode]) {
        if let children {
            for child in children { child.collectFiles(matching: q, into: &result) }
        } else if q.isEmpty || name.lowercased().contains(q) {
            result.append(self)
        }
    }

    /// Find a node in the subtree by URL (path-based match, tolerant of trailing-slash differences).
    func node(withURL target: URL) -> FileNode? {
        if url.path == target.path { return self }
        if let children {
            for child in children {
                if let match = child.node(withURL: target) { return match }
            }
        }
        return nil
    }

    /// Every node URL in the subtree (this node plus all descendants, files and directories).
    /// Used to detect structural changes (added/removed entries) for live reload.
    func allURLs() -> Set<URL> {
        var set: Set<URL> = [url]
        if let children {
            for child in children { set.formUnion(child.allURLs()) }
        }
        return set
    }
}
