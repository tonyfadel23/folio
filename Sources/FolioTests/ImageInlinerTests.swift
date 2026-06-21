import Foundation
import FolioCore

func runImageInlinerTests() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("nativemd-img-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let png = dir.appendingPathComponent("pix.png")
    try? Data("fake-png-bytes".utf8).write(to: png)

    T.test("inlines a local image as a base64 data URI") {
        let out = PreviewHTML.inlineLocalImages(in: "<img src=\"pix.png\" alt=\"x\">", baseDir: dir)
        T.contains(out, "data:image/png;base64,")
        T.expect(!out.contains("src=\"pix.png\""), "relative src should be replaced")
    }

    T.test("maps common extensions to the right mime type") {
        T.equal(PreviewHTML.imageMimeType(for: URL(fileURLWithPath: "/a/b.png")), "image/png")
        T.equal(PreviewHTML.imageMimeType(for: URL(fileURLWithPath: "/a/b.jpg")), "image/jpeg")
        T.equal(PreviewHTML.imageMimeType(for: URL(fileURLWithPath: "/a/b.jpeg")), "image/jpeg")
        T.equal(PreviewHTML.imageMimeType(for: URL(fileURLWithPath: "/a/b.gif")), "image/gif")
        T.equal(PreviewHTML.imageMimeType(for: URL(fileURLWithPath: "/a/b.svg")), "image/svg+xml")
    }

    T.test("leaves remote and data URLs untouched") {
        T.contains(PreviewHTML.inlineLocalImages(in: "<img src=\"https://x/y.png\">", baseDir: dir), "https://x/y.png")
        T.contains(PreviewHTML.inlineLocalImages(in: "<img src=\"data:image/png;base64,QQ==\">", baseDir: dir), "data:image/png;base64,QQ==")
    }

    T.test("leaves missing local files untouched") {
        T.contains(PreviewHTML.inlineLocalImages(in: "<img src=\"nope.png\">", baseDir: dir), "nope.png")
    }

    T.test("handles percent-encoded filenames with spaces") {
        let spaced = dir.appendingPathComponent("my pic.png")
        try? Data("x".utf8).write(to: spaced)
        let out = PreviewHTML.inlineLocalImages(in: "<img src=\"my%20pic.png\">", baseDir: dir)
        T.contains(out, "data:image/png;base64,")
    }

    T.test("a selected image file builds to a data-URI document") {
        let url = dir.appendingPathComponent("photo.png")
        try? Data("not really a png".utf8).write(to: url)
        guard case let .html(html) = PreviewHTML().build(for: url) else {
            T.expect(false, "expected .html for image"); return
        }
        T.contains(html, "<img")
        T.contains(html, "data:image/png;base64,")
    }
}
