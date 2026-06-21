import Foundation

/// Embedded CSS for the preview pane. Kept as a Swift string so the app needs no
/// resource bundle — supports light/dark mode and a readable, GitHub-ish layout.
public enum Styles {
    /// A unique signature embedded in the CSS so tests can assert the stylesheet was injected.
    public static let marker = "/* nativemd-styles */"

    public static let css: String = """
    \(marker)
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
        font-size: 15px;
        line-height: 1.6;
        color: #1d1d1f;
        background: #ffffff;
        padding: 28px 36px;
        max-width: 860px;
        margin: 0 auto;
        word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 { font-weight: 600; line-height: 1.25; margin: 1.4em 0 0.5em; }
    h1 { font-size: 1.9em; border-bottom: 1px solid #e3e3e6; padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid #ececef; padding-bottom: 0.25em; }
    h3 { font-size: 1.25em; }
    p { margin: 0.7em 0; }
    a { color: #0066cc; text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul, ol { padding-left: 1.6em; margin: 0.6em 0; }
    li { margin: 0.25em 0; }
    blockquote {
        margin: 0.8em 0; padding: 0.2em 1em;
        border-left: 4px solid #d0d0d4; color: #5a5a5f;
    }
    code {
        font-family: "SF Mono", ui-monospace, Menlo, Monaco, "Courier New", monospace;
        font-size: 0.88em;
        background: rgba(135,131,120,0.15);
        padding: 0.15em 0.35em; border-radius: 4px;
    }
    pre {
        position: relative;
        background: #f6f6f7; padding: 14px 16px; border-radius: 8px;
        overflow: auto; line-height: 1.45;
    }
    pre code { background: none; padding: 0; font-size: 0.85em; }
    .copy-btn {
        position: absolute; top: 8px; right: 8px;
        font: inherit; font-size: 0.72em;
        padding: 3px 9px; border-radius: 6px;
        border: 1px solid rgba(128,128,128,0.35);
        background: rgba(255,255,255,0.85); color: #444;
        cursor: pointer; opacity: 0; transition: opacity 0.12s;
    }
    pre:hover .copy-btn { opacity: 1; }
    li.task { list-style: none; margin-left: -1.2em; }
    li.task input { margin-right: 0.5em; }
    table { border-collapse: collapse; margin: 1em 0; }
    th, td { border: 1px solid #d8d8dc; padding: 6px 12px; }
    th { background: #f2f2f4; }
    img { max-width: 100%; height: auto; border-radius: 6px; }
    hr { border: none; border-top: 1px solid #e3e3e6; margin: 1.6em 0; }
    .nativemd-image-page { text-align: center; padding-top: 8px; }
    .nativemd-placeholder { color: #86868b; text-align: center; margin-top: 24vh; font-size: 1.05em; }
    @media (prefers-color-scheme: dark) {
        body { color: #e8e8ea; background: #1e1e1e; }
        h1 { border-bottom-color: #3a3a3c; }
        h2 { border-bottom-color: #323234; }
        a { color: #4ea1ff; }
        blockquote { border-left-color: #48484a; color: #a8a8ad; }
        code { background: rgba(255,255,255,0.10); }
        pre { background: #2a2a2c; }
        .copy-btn { background: rgba(60,60,62,0.9); color: #ddd; border-color: rgba(255,255,255,0.18); }
        th, td { border-color: #3a3a3c; }
        th { background: #2a2a2c; }
        hr { border-top-color: #3a3a3c; }
    }
    """
}
