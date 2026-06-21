import Foundation
import FolioCore

private func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("nativemd-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func write(_ contents: String, to dir: URL, named name: String) -> URL {
    let url = dir.appendingPathComponent(name)
    try? contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

func runPreviewHTMLTests() {
    let builder = PreviewHTML()
    let dir = tempDir()

    T.test("document wraps body with stylesheet and title") {
        let doc = PreviewHTML.document(title: "My Title", body: "<p>hello</p>")
        T.contains(doc, "<style>")
        T.contains(doc, Styles.marker)        // our CSS signature is present
        T.contains(doc, "<p>hello</p>")
        T.contains(doc, "My Title")
        T.contains(doc, "<!DOCTYPE html>")
        T.contains(doc, "clipboard") // copy-code button script is injected
    }

    T.test("document includes strict Content-Security-Policy meta") {
        let doc = PreviewHTML.document(title: "x", body: "<p>y</p>")
        T.contains(doc, "Content-Security-Policy")
        T.contains(doc, "default-src 'none'")   // hard floor: nothing loads unless allowlisted
        T.contains(doc, "connect-src 'none'")   // no fetch/XHR/sendBeacon to attacker URLs
        T.contains(doc, "form-action 'none'")   // no form-POST exfiltration
        T.contains(doc, "base-uri 'none'")      // no <base href> URL hijacking
        // Inline JS is still allowed so interactive HTML (and our copy-code-block script) work.
        T.contains(doc, "script-src 'unsafe-inline'")
    }

    T.test("escape neutralizes HTML metacharacters") {
        T.equal(PreviewHTML.escape("<a> & <b>"), "&lt;a&gt; &amp; &lt;b&gt;")
    }

    T.test("markdown file renders to html document") {
        let url = write("# Title\n\nbody text", to: dir, named: "doc.md")
        guard case let .html(html) = builder.build(for: url) else {
            T.expect(false, "expected .html for markdown"); return
        }
        T.contains(html, "<h1>Title</h1>")
        T.contains(html, "body text")
        T.contains(html, Styles.marker)
    }

    T.test("html file is passed through inside a document") {
        let url = write("<p class=\"raw\">raw html</p>", to: dir, named: "page.html")
        guard case let .html(html) = builder.build(for: url) else {
            T.expect(false, "expected .html for html file"); return
        }
        T.contains(html, "<p class=\"raw\">raw html</p>")
    }

    T.test("image file produces an img tag referencing the file name") {
        let url = write("not really a png", to: dir, named: "photo.png")
        guard case let .html(html) = builder.build(for: url) else {
            T.expect(false, "expected .html for image"); return
        }
        T.contains(html, "<img")
        T.contains(html, "photo.png")
    }

    T.test("text file is shown escaped inside a pre block") {
        let url = write("let x = 1 < 2", to: dir, named: "code.swift")
        guard case let .html(html) = builder.build(for: url) else {
            T.expect(false, "expected .html for text"); return
        }
        T.contains(html, "<pre")
        T.contains(html, "1 &lt; 2")          // escaped
    }

    T.test("pdf file loads the file url directly") {
        let url = write("%PDF-1.4 fake", to: dir, named: "doc.pdf")
        T.equal(builder.build(for: url), .loadFile(url))
    }

    T.test("unknown binary type yields an empty placeholder") {
        let url = write("PK\u{0003}\u{0004}", to: dir, named: "archive.zip")
        guard case .empty = builder.build(for: url) else {
            T.expect(false, "expected .empty for unknown type"); return
        }
    }
}
