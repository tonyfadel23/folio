import Foundation

/// Embedded CSS for the preview pane. Kept as a Swift string so the app needs no
/// resource bundle. Colors are defined as CSS custom properties on `body`, with
/// per-theme overrides keyed off body classes set by `PreviewHTML.document(theme:)`:
///   - `body.theme-light`  → light palette (also the default if no class is set)
///   - `body.theme-dark`   → dark palette (always dark, regardless of system)
///   - `body.theme-system` → light by default; dark under `prefers-color-scheme: dark`
public enum Styles {
    /// A unique signature embedded in the CSS so tests can assert the stylesheet was injected.
    public static let marker = "/* folio-styles */"

    public static let css: String = """
    \(marker)
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }

    /* Light palette — applies by default and explicitly for body.theme-light. */
    body {
        --fg: #1d1d1f;
        --bg: #ffffff;
        --muted-fg: #5a5a5f;
        --placeholder-fg: #86868b;
        --link: #0066cc;
        --border: #e3e3e6;
        --border-soft: #ececef;
        --code-bg: rgba(135, 131, 120, 0.15);
        --pre-bg: #f6f6f7;
        --th-bg: #f2f2f4;
        --btn-bg: rgba(255, 255, 255, 0.85);
        --btn-fg: #444;
        --btn-border: rgba(128, 128, 128, 0.35);

        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
        font-size: 15px;
        line-height: 1.6;
        color: var(--fg);
        background: var(--bg);
        padding: 28px 36px;
        max-width: 860px;
        margin: 0 auto;
        word-wrap: break-word;
    }

    /* Dark palette — always applied for explicit dark; applied for system mode under
       prefers-color-scheme: dark. */
    body.theme-dark,
    body.theme-system {
        /* placeholder so the selector exists; per-mode overrides follow below. */
    }
    body.theme-dark {
        --fg: #e8e8ea;
        --bg: #1e1e1e;
        --muted-fg: #a8a8ad;
        --placeholder-fg: #8a8a90;
        --link: #4ea1ff;
        --border: #3a3a3c;
        --border-soft: #323234;
        --code-bg: rgba(255, 255, 255, 0.10);
        --pre-bg: #2a2a2c;
        --th-bg: #2a2a2c;
        --btn-bg: rgba(60, 60, 62, 0.9);
        --btn-fg: #dddddd;
        --btn-border: rgba(255, 255, 255, 0.18);
    }
    @media (prefers-color-scheme: dark) {
        body.theme-system {
            --fg: #e8e8ea;
            --bg: #1e1e1e;
            --muted-fg: #a8a8ad;
            --placeholder-fg: #8a8a90;
            --link: #4ea1ff;
            --border: #3a3a3c;
            --border-soft: #323234;
            --code-bg: rgba(255, 255, 255, 0.10);
            --pre-bg: #2a2a2c;
            --th-bg: #2a2a2c;
            --btn-bg: rgba(60, 60, 62, 0.9);
            --btn-fg: #dddddd;
            --btn-border: rgba(255, 255, 255, 0.18);
        }
    }

    h1, h2, h3, h4, h5, h6 { font-weight: 600; line-height: 1.25; margin: 1.4em 0 0.5em; }
    h1 { font-size: 1.9em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid var(--border-soft); padding-bottom: 0.25em; }
    h3 { font-size: 1.25em; }
    p { margin: 0.7em 0; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul, ol { padding-left: 1.6em; margin: 0.6em 0; }
    li { margin: 0.25em 0; }
    blockquote {
        margin: 0.8em 0; padding: 0.2em 1em;
        border-left: 4px solid var(--border); color: var(--muted-fg);
    }
    code {
        font-family: "SF Mono", ui-monospace, Menlo, Monaco, "Courier New", monospace;
        font-size: 0.88em;
        background: var(--code-bg);
        padding: 0.15em 0.35em; border-radius: 4px;
    }
    pre {
        position: relative;
        background: var(--pre-bg); padding: 14px 16px; border-radius: 8px;
        overflow: auto; line-height: 1.45;
    }
    pre code { background: none; padding: 0; font-size: 0.85em; }
    .copy-btn {
        position: absolute; top: 8px; right: 8px;
        font: inherit; font-size: 0.72em;
        padding: 3px 9px; border-radius: 6px;
        border: 1px solid var(--btn-border);
        background: var(--btn-bg); color: var(--btn-fg);
        cursor: pointer; opacity: 0; transition: opacity 0.12s;
    }
    pre:hover .copy-btn { opacity: 1; }
    li.task { list-style: none; margin-left: -1.2em; }
    li.task input { margin-right: 0.5em; }
    table { border-collapse: collapse; margin: 1em 0; }
    th, td { border: 1px solid var(--border); padding: 6px 12px; }
    th { background: var(--th-bg); }
    img { max-width: 100%; height: auto; border-radius: 6px; }
    hr { border: none; border-top: 1px solid var(--border); margin: 1.6em 0; }
    .nativemd-image-page { text-align: center; padding-top: 8px; }
    .nativemd-placeholder { color: var(--placeholder-fg); text-align: center; margin-top: 24vh; font-size: 1.05em; }
    """
}
