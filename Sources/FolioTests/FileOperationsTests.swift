import Foundation
import FolioCore

func runFileOperationsTests() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("nativemd-ops-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    T.test("moveToTrash removes the file from its original location") {
        let file = dir.appendingPathComponent("todelete.txt")
        try "bye".write(to: file, atomically: true, encoding: .utf8)
        T.expect(fm.fileExists(atPath: file.path), "precondition: file should exist")

        let trashed = try FileOperations.moveToTrash(file)

        T.expect(!fm.fileExists(atPath: file.path), "file should be gone from its source path")
        // Clean up the item we just put in the Trash.
        if let trashed { try? fm.removeItem(at: trashed) }
    }

    T.test("moveToTrash throws for a nonexistent path") {
        let missing = dir.appendingPathComponent("nope-\(UUID().uuidString).txt")
        var threw = false
        do { _ = try FileOperations.moveToTrash(missing) } catch { threw = true }
        T.expect(threw, "trashing a missing file should throw")
    }

    T.test("rename moves the item to the new name in the same folder") {
        let file = dir.appendingPathComponent("before.md")
        try "hi".write(to: file, atomically: true, encoding: .utf8)

        let newURL = try FileOperations.rename(file, to: "after.md")

        T.equal(newURL.lastPathComponent, "after.md")
        T.expect(!fm.fileExists(atPath: file.path), "old name should no longer exist")
        T.expect(fm.fileExists(atPath: newURL.path), "new name should exist")
        T.equal(newURL.deletingLastPathComponent().path, dir.path) // stays in same folder
    }

    T.test("rename trims whitespace and rejects empty names") {
        let file = dir.appendingPathComponent("keep.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        var threw = false
        do { _ = try FileOperations.rename(file, to: "   ") } catch { threw = true }
        T.expect(threw, "blank name should be rejected")
    }

    T.test("rename rejects names containing a path separator") {
        let file = dir.appendingPathComponent("safe.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        var threw = false
        do { _ = try FileOperations.rename(file, to: "a/b.txt") } catch { threw = true }
        T.expect(threw, "names with '/' should be rejected")
    }

    T.test("move relocates a file into another folder") {
        let sub = dir.appendingPathComponent("dest-\(UUID().uuidString)")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("movable.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        let newURL = try FileOperations.move(file, into: sub)

        T.expect(!fm.fileExists(atPath: file.path), "should leave the source location")
        T.expect(fm.fileExists(atPath: newURL.path), "should exist at destination")
        T.equal(newURL.deletingLastPathComponent().lastPathComponent, sub.lastPathComponent)
    }

    T.test("move into the current parent is rejected as same-location") {
        let file = dir.appendingPathComponent("stay.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        var err: FileOperations.OperationError?
        do { _ = try FileOperations.move(file, into: dir) }
        catch let e as FileOperations.OperationError { err = e }
        T.equal(err, .sameLocation)
    }

    T.test("move a folder into its own descendant is rejected") {
        let parent = dir.appendingPathComponent("p-\(UUID().uuidString)")
        let child = parent.appendingPathComponent("child")
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        var err: FileOperations.OperationError?
        do { _ = try FileOperations.move(parent, into: child) }
        catch let e as FileOperations.OperationError { err = e }
        T.equal(err, .invalidDestination)
    }
}
