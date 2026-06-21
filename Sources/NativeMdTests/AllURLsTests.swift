import Foundation
import NativeMdCore

func runAllURLsTests() {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("nativemd-urls-\(UUID().uuidString)")
    let beta = root.appendingPathComponent("Beta")
    try? fm.createDirectory(at: beta, withIntermediateDirectories: true)
    try? fm.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
    try? "x".write(to: beta.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    try? "x".write(to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)

    let tree = FileTreeLoader.load(root)

    T.test("allURLs collects every node (dirs + files) including root") {
        let urls = tree.allURLs()
        // root, alpha, Beta, Beta/a.txt, note.md
        T.equal(urls.count, 5)
        T.expect(urls.contains { $0.lastPathComponent == root.lastPathComponent }, "should contain root")
        T.expect(urls.contains { $0.lastPathComponent == "a.txt" }, "should contain nested file")
    }

    T.test("allURLs distinguishes structural changes (added file)") {
        let before = tree.allURLs()
        try? "x".write(to: root.appendingPathComponent("new.md"), atomically: true, encoding: .utf8)
        let after = FileTreeLoader.load(root).allURLs()
        T.expect(after != before, "URL set should change when a file is added")
        T.equal(after.count, before.count + 1)
    }
}
