import Foundation
import NativeMdCore

func runPreviewModeTests() {
    T.test("formats with a rendered view offer a toggle; plain ones don't") {
        T.equal(FileKind.markdown.previewToggle?.rendered, "Formatted")
        T.equal(FileKind.markdown.previewToggle?.raw, "Raw")
        T.equal(FileKind.html.previewToggle?.rendered, "Website")
        T.equal(FileKind.html.previewToggle?.raw, "Code")
        T.equal(FileKind.csv.previewToggle?.rendered, "Table")
        T.equal(FileKind.csv.previewToggle?.raw, "Raw")
        T.equal(FileKind.json.previewToggle?.rendered, "Pretty")
        T.equal(FileKind.xml.previewToggle?.rendered, "Formatted")
        T.equal(FileKind.svg.previewToggle?.rendered, "Image")
        T.equal(FileKind.svg.previewToggle?.raw, "Code")
        T.expect(FileKind.image.previewToggle == nil, "image has no toggle")
        T.expect(FileKind.pdf.previewToggle == nil, "pdf has no toggle")
        T.expect(FileKind.text.previewToggle == nil, "text has no toggle")
        T.expect(FileKind.other.previewToggle == nil, "other has no toggle")
    }

    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("nativemd-mode-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let builder = PreviewHTML()

    T.test("markdown raw shows escaped source, not rendered HTML") {
        let url = dir.appendingPathComponent("doc.md")
        try? "# Title\n\nbody".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(html) = builder.build(for: url, raw: true) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(html, "<pre")
        T.contains(html, "# Title")      // literal markdown shown
        T.expect(!html.contains("<h1>Title</h1>"), "raw must not render headings")
    }

    T.test("markdown rendered still produces formatted HTML") {
        let url = dir.appendingPathComponent("doc2.md")
        try? "# Title".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(html) = builder.build(for: url, raw: false) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(html, "<h1>Title</h1>")
    }

    T.test("html raw shows escaped source") {
        let url = dir.appendingPathComponent("page.html")
        try? "<p>hi</p>".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(html) = builder.build(for: url, raw: true) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(html, "&lt;p&gt;hi&lt;/p&gt;")
    }

    T.test("csv renders as a table; raw shows source") {
        let url = dir.appendingPathComponent("data.csv")
        try? "name,age\nAda,36".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(rendered) = builder.build(for: url, raw: false) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(rendered, "<table")
        T.contains(rendered, "<th>name</th>")
        T.contains(rendered, "<td>Ada</td>")
        guard case let .html(raw) = builder.build(for: url, raw: true) else {
            T.expect(false, "expected .html raw"); return
        }
        T.contains(raw, "<pre")
        T.contains(raw, "name,age")
    }

    T.test("json pretty-prints when rendered") {
        let url = dir.appendingPathComponent("d.json")
        try? "{\"a\":1}".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(html) = builder.build(for: url, raw: false) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(html, "<pre")
        T.contains(html, "&quot;a&quot;") // key rendered (quotes escaped for HTML)
    }

    T.test("xml formats when rendered") {
        let url = dir.appendingPathComponent("d.xml")
        try? "<a><b>1</b></a>".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(html) = builder.build(for: url, raw: false) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(html, "<pre")
        T.contains(html, "&lt;b&gt;1&lt;/b&gt;")
    }

    T.test("svg renders as an image, raw shows markup") {
        let url = dir.appendingPathComponent("v.svg")
        try? "<svg xmlns='http://www.w3.org/2000/svg'></svg>".write(to: url, atomically: true, encoding: .utf8)
        guard case let .html(rendered) = builder.build(for: url, raw: false) else {
            T.expect(false, "expected .html"); return
        }
        T.contains(rendered, "data:image/svg+xml;base64,") // inlined as an image
        guard case let .html(raw) = builder.build(for: url, raw: true) else {
            T.expect(false, "expected .html raw"); return
        }
        T.contains(raw, "&lt;svg")
    }
}
