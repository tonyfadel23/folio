import Foundation
import NativeMdCore

private func makeTree() -> (root: URL, node: FileNode) {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("nativemd-more-\(UUID().uuidString)")
    let beta = root.appendingPathComponent("Beta")
    try? fm.createDirectory(at: beta, withIntermediateDirectories: true)
    try? fm.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
    try? "x".write(to: beta.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("Zebra.md"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)
    return (root, FileTreeLoader.load(root))
}

func runBoundedLoadTests() {
    let (root, _) = makeTree()

    T.test("default load of a small tree is not truncated") {
        let result = FileTreeLoader.load(root, limits: .default)
        T.expect(!result.truncated, "small tree should not truncate")
        T.equal(result.root.children?.count, 4)
    }

    T.test("maxEntries caps the number of entries and flags truncation") {
        let result = FileTreeLoader.load(root, limits: LoadLimits(maxEntries: 2, maxDepth: 32))
        T.expect(result.truncated, "should flag truncation when capped")
        T.equal(result.root.children?.count, 2) // dirs first: alpha, Beta
    }

    T.test("maxDepth stops descent and flags truncation") {
        let result = FileTreeLoader.load(root, limits: LoadLimits(maxEntries: 100, maxDepth: 1))
        T.expect(result.truncated, "should flag truncation when depth-limited")
        let beta = (result.root.children ?? []).first { $0.name == "Beta" }
        T.equal(beta?.children?.count, 0) // listed but not descended
    }

    T.test("convenience load() returns the full tree root") {
        let node = FileTreeLoader.load(root)
        T.equal(node.children?.count, 4)
    }
}

func runNodeFinderTests() {
    let (_, tree) = makeTree()

    T.test("finds a descendant file by URL") {
        guard let target = tree.matchingFiles(query: "a.txt").first else {
            T.expect(false, "fixture missing a.txt"); return
        }
        let found = tree.node(withURL: target.url)
        T.equal(found?.name, "a.txt")
    }

    T.test("returns nil for a URL not in the tree") {
        T.expect(tree.node(withURL: URL(fileURLWithPath: "/no/such/file.md")) == nil,
                 "should not find a foreign URL")
    }
}
