import Foundation
import FolioCore

func runFileTreeLoaderTests() {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("nativemd-tree-\(UUID().uuidString)")
    let beta = root.appendingPathComponent("Beta")
    try? fm.createDirectory(at: beta, withIntermediateDirectories: true)
    try? fm.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
    try? "x".write(to: beta.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("Zebra.md"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent(".secret"), atomically: true, encoding: .utf8)

    let tree = FileTreeLoader.load(root)

    T.test("root is a directory node") {
        T.expect(tree.isDirectory, "root should be a directory")
        T.equal(tree.name, root.lastPathComponent)
    }

    T.test("hidden dotfiles are excluded") {
        let names = (tree.children ?? []).map(\.name)
        T.expect(!names.contains(".secret"), "hidden file should be excluded; got \(names)")
        T.equal(names.count, 4)
    }

    T.test("directories sort before files, each case-insensitive A–Z") {
        let names = (tree.children ?? []).map(\.name)
        T.equal(names, ["alpha", "Beta", "apple.txt", "Zebra.md"])
    }

    T.test("files have nil children, directories have an array") {
        let children = tree.children ?? []
        let apple = children.first { $0.name == "apple.txt" }
        let alpha = children.first { $0.name == "alpha" }
        T.expect(apple?.children == nil, "file should have nil children")
        T.expect(alpha?.children != nil, "directory should have a children array")
    }

    T.test("nested directory contents load recursively") {
        let betaNode = (tree.children ?? []).first { $0.name == "Beta" }
        T.equal(betaNode?.children?.count, 1)
        T.equal(betaNode?.children?.first?.name, "a.txt")
    }

    T.test("nodes are identified and hashed by url only") {
        let a = FileNode(url: URL(fileURLWithPath: "/tmp/x.md"), isDirectory: false, children: nil)
        let b = FileNode(url: URL(fileURLWithPath: "/tmp/x.md"), isDirectory: false, children: nil)
        T.equal(a, b)
        T.equal(a.id, b.id)
    }
}
