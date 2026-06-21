import Foundation
import NativeMdCore

private func kind(_ name: String) -> FileKind {
    FileKind(for: URL(fileURLWithPath: "/tmp/\(name)"))
}

func runFileKindTests() {
    T.test("markdown extensions") {
        T.equal(kind("README.md"), .markdown)
        T.equal(kind("notes.markdown"), .markdown)
        T.equal(kind("DOC.MD"), .markdown) // case-insensitive
    }
    T.test("html extensions") {
        T.equal(kind("index.html"), .html)
        T.equal(kind("page.htm"), .html)
    }
    T.test("image extensions") {
        T.equal(kind("photo.png"), .image)
        T.equal(kind("pic.jpg"), .image)
        T.equal(kind("pic.jpeg"), .image)
        T.equal(kind("anim.gif"), .image)
        T.equal(kind("modern.webp"), .image)
    }
    T.test("structured formats get their own kind") {
        T.equal(kind("data.csv"), .csv)
        T.equal(kind("data.tsv"), .csv)
        T.equal(kind("data.json"), .json)
        T.equal(kind("doc.xml"), .xml)
        T.equal(kind("Info.plist"), .xml)
        T.equal(kind("vec.svg"), .svg)
    }
    T.test("pdf extension") {
        T.equal(kind("doc.pdf"), .pdf)
    }
    T.test("text extensions") {
        T.equal(kind("notes.txt"), .text)
        T.equal(kind("main.swift"), .text)
        T.equal(kind("app.js"), .text)
        T.equal(kind("style.css"), .text)
    }
    T.test("unknown is other") {
        T.equal(kind("archive.zip"), .other)
        T.equal(kind("binary.bin"), .other)
        T.equal(kind("noextension"), .other)
    }
    T.test("extension-less config/dotfiles preview as text") {
        T.equal(kind(".gitignore"), .text)
        T.equal(kind(".env"), .text)
        T.equal(kind(".gitattributes"), .text)
        T.equal(kind(".dockerignore"), .text)
        T.equal(kind("Makefile"), .text)
        T.equal(kind("Dockerfile"), .text)
        T.equal(kind("LICENSE"), .text)
        T.equal(kind("README"), .text)
    }
}

func runHiddenFlagTests() {
    func node(_ name: String, dir: Bool = false) -> FileNode {
        FileNode(url: URL(fileURLWithPath: "/tmp/\(name)"), isDirectory: dir, children: dir ? [] : nil)
    }
    T.test("dot-prefixed names are hidden") {
        T.expect(node(".git", dir: true).isHidden, ".git should be hidden")
        T.expect(node(".env").isHidden, ".env should be hidden")
    }
    T.test("normal names are not hidden") {
        T.expect(!node("README.md").isHidden, "README.md should not be hidden")
        T.expect(!node("src", dir: true).isHidden, "src should not be hidden")
    }
}
