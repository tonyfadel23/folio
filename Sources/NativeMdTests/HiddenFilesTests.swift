import Foundation
import NativeMdCore

func runHiddenFilesTests() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("nativemd-hidden-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    try? "x".write(to: dir.appendingPathComponent("visible.md"), atomically: true, encoding: .utf8)
    try? "x".write(to: dir.appendingPathComponent(".secret"), atomically: true, encoding: .utf8)
    try? fm.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)

    T.test("hidden entries are excluded by default") {
        let names = (FileTreeLoader.load(dir, limits: .default).root.children ?? []).map(\.name)
        T.expect(!names.contains(".secret"), "dotfile should be hidden; got \(names)")
        T.expect(!names.contains(".git"), "dot-folder should be hidden; got \(names)")
        T.expect(names.contains("visible.md"), "normal file should show")
    }

    T.test("hidden entries are included when requested") {
        let names = (FileTreeLoader.load(dir, limits: .default, includeHidden: true).root.children ?? []).map(\.name)
        T.expect(names.contains(".secret"), "dotfile should be shown; got \(names)")
        T.expect(names.contains(".git"), "dot-folder should be shown; got \(names)")
        T.expect(names.contains("visible.md"), "normal file should still show")
    }
}
