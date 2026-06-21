import Foundation
import NativeMdCore

func runMarkdownRendererTests() {
    let r = MarkdownRenderer()

    T.test("renders headings") {
        T.contains(r.html(from: "# Hi"), "<h1>Hi</h1>")
    }
    T.test("renders bold and italic") {
        let html = r.html(from: "**bold** and *italic*")
        T.contains(html, "<strong>bold</strong>")
        T.contains(html, "<em>italic</em>")
    }
    T.test("renders links") {
        let html = r.html(from: "[site](https://example.com)")
        T.contains(html, "href=\"https://example.com\"")
        T.contains(html, ">site</a>")
    }
    T.test("renders unordered lists") {
        let html = r.html(from: "- one\n- two")
        T.contains(html, "<ul>")
        T.contains(html, "<li>one</li>")
        T.contains(html, "<li>two</li>")
    }
    T.test("renders fenced code blocks") {
        let html = r.html(from: "```\nlet x = 1\n```")
        T.contains(html, "<code>")
        T.contains(html, "let x = 1")
    }
    T.test("renders inline code") {
        T.contains(r.html(from: "Use `print()` here"), "<code>print()</code>")
    }
    T.test("renders strikethrough (already supported by Ink)") {
        T.contains(r.html(from: "~~gone~~"), "<s>gone</s>")
    }
    T.test("converts task list items into checkboxes") {
        let html = r.html(from: "- [ ] todo\n- [x] done")
        T.contains(html, "type=\"checkbox\"")
        T.contains(html, "checked")
        T.expect(!html.contains("[ ]"), "raw [ ] marker should be replaced")
    }
}
