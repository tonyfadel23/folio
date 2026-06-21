import Foundation
import NativeMdCore

func runFileFilterTests() {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("nativemd-filter-\(UUID().uuidString)")
    let beta = root.appendingPathComponent("Beta")
    try? fm.createDirectory(at: beta, withIntermediateDirectories: true)
    try? fm.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true) // empty dir
    try? "x".write(to: beta.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("Zebra.md"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)

    let tree = FileTreeLoader.load(root)
    func names(_ q: String) -> [String] { tree.matchingFiles(query: q).map(\.name) }

    T.test("matches files by case-insensitive substring, pre-order") {
        T.equal(names("txt"), ["a.txt", "apple.txt"])
        T.equal(names("APPLE"), ["apple.txt"])
        T.equal(names("md"), ["Zebra.md"])
    }

    T.test("no match yields empty result") {
        T.equal(names("nope"), [])
    }

    T.test("empty query returns all files (directories excluded)") {
        T.equal(names(""), ["a.txt", "apple.txt", "Zebra.md"])
        T.equal(names("   "), ["a.txt", "apple.txt", "Zebra.md"])
    }

    T.test("results are file nodes, never directories") {
        for node in tree.matchingFiles(query: "a") {
            T.expect(!node.isDirectory, "\(node.name) should be a file, not a directory")
        }
    }
}
