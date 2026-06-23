import Foundation
import Ink

/// Converts Markdown source into an HTML body fragment using the pure-Swift Ink parser.
public struct MarkdownRenderer {
    private let parser: MarkdownParser

    public init() {
        self.parser = MarkdownParser()
    }

    /// Render `markdown` to an HTML fragment (no surrounding `<html>`/`<body>`).
    /// YAML frontmatter (`---` block at the top) is stripped before parsing so it doesn't
    /// render as raw text + horizontal rules — see `stripFrontmatter`.
    public func html(from markdown: String) -> String {
        Self.applyTaskLists(to: parser.html(from: Self.stripFrontmatter(markdown)))
    }

    /// Strip a leading YAML frontmatter block (an opening `---` line on line 1, followed by
    /// YAML, followed by a matching closing `---` line) so it doesn't render in the preview.
    /// Frontmatter is metadata for the system that consumes the file — Jekyll/Hugo/Astro
    /// pages, Obsidian notes, Claude Code skills, etc. — not content meant for the human
    /// previewing the body. The Raw toggle still shows the full source, so power users who
    /// need to inspect the YAML can flip to it.
    ///
    /// If the file's opening `---` has no matching closing line, the original markdown is
    /// returned unchanged (the `---` was a horizontal rule, not frontmatter).
    static func stripFrontmatter(_ markdown: String) -> String {
        // Normalize CRLF -> LF only for the detection pass; either is valid input.
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else { return markdown }

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        for i in 1..<lines.count where lines[i].trimmingCharacters(in: .whitespaces) == "---" {
            return lines[(i + 1)...].joined(separator: "\n")
        }
        // No closing marker — opening `---` was a thematic break, not frontmatter.
        return markdown
    }

    /// Ink emits task-list items as literal text (`<li>[ ] …`). Convert them to real,
    /// disabled checkboxes (GitHub-style). Strikethrough and tables are already handled by Ink.
    static func applyTaskLists(to html: String) -> String {
        html
            .replacingOccurrences(of: "<li>[ ] ", with: "<li class=\"task\"><input type=\"checkbox\" disabled> ")
            .replacingOccurrences(of: "<li>[x] ", with: "<li class=\"task\"><input type=\"checkbox\" checked disabled> ")
            .replacingOccurrences(of: "<li>[X] ", with: "<li class=\"task\"><input type=\"checkbox\" checked disabled> ")
    }
}
