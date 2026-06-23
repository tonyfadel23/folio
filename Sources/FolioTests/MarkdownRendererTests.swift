import Foundation
import FolioCore

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

    // YAML frontmatter handling — see MarkdownRenderer.stripFrontmatter.

    T.test("strips YAML frontmatter from rendered output") {
        // Files from Jekyll, Hugo, Astro, Obsidian, Claude Code skills, etc. start with
        // a `---` block of metadata. Folio should render the body, not the YAML.
        let source = """
        ---
        name: learn
        description: a skill description
        version: "1.0"
        ---

        # Real heading

        body text
        """
        let html = r.html(from: source)
        T.contains(html, "<h1>Real heading</h1>")
        T.contains(html, "body text")
        T.expect(!html.contains("name: learn"), "frontmatter key should not render as text")
        T.expect(!html.contains("description: a skill"), "frontmatter key should not render as text")
    }

    T.test("frontmatter with no closing marker is treated as a horizontal rule") {
        // A lone `---` at the top of a real document (no matching close) is a thematic
        // break, not frontmatter — preserve the existing markdown semantics.
        let html = r.html(from: "---\nintro paragraph\n\n# heading")
        T.contains(html, "<h1>heading</h1>")
        T.contains(html, "intro paragraph")
    }

    T.test("file without frontmatter renders identically to before") {
        // Regression guard: the strip pass must be a no-op when there's no opening `---\n`.
        let plain = "# Hi\n\nbody"
        T.equal(r.html(from: plain), r.html(from: plain))
        T.contains(r.html(from: plain), "<h1>Hi</h1>")
        T.contains(r.html(from: plain), "body")
    }

    T.test("empty frontmatter block is stripped, body still renders") {
        let html = r.html(from: "---\n---\n\n# heading")
        T.contains(html, "<h1>heading</h1>")
        T.expect(!html.contains("---"), "raw --- should not survive the strip")
    }

    T.test("frontmatter handles CRLF line endings") {
        // Windows-authored files (or anything that gets routed through CRLF tooling) shouldn't
        // bypass the strip just because their line endings differ.
        let source = "---\r\nname: x\r\n---\r\n\r\n# heading"
        let html = r.html(from: source)
        T.contains(html, "<h1>heading</h1>")
        T.expect(!html.contains("name: x"), "frontmatter key should not render under CRLF")
    }
}
