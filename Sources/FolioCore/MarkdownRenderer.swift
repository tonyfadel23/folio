import Foundation
import Ink

/// Converts Markdown source into an HTML body fragment using the pure-Swift Ink parser.
public struct MarkdownRenderer {
    private let parser: MarkdownParser

    public init() {
        self.parser = MarkdownParser()
    }

    /// Render `markdown` to an HTML fragment (no surrounding `<html>`/`<body>`).
    public func html(from markdown: String) -> String {
        Self.applyTaskLists(to: parser.html(from: markdown))
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
