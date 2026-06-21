import Foundation

/// The instruction the preview pane should carry out for a given file.
public enum PreviewContent: Equatable {
    /// Render this HTML string (baseURL is set to the file's parent directory by the view).
    case html(String)
    /// Load this file URL directly in the webview (e.g. PDF, which WebKit renders natively).
    case loadFile(URL)
    /// Show a plain placeholder message (no preview available / unreadable).
    case empty(String)
}

/// Builds the preview payload for a file, routing by `FileKind`. The disk read happens
/// here; the pure helpers (`document`, `escape`) are exposed for testing.
public struct PreviewHTML {
    private let markdown: MarkdownRenderer

    public init() {
        self.markdown = MarkdownRenderer()
    }

    public func build(for url: URL, raw: Bool = false) -> PreviewContent {
        let baseDir = url.deletingLastPathComponent()
        let kind = FileKind(for: url)

        // Raw mode: show the file's own source (escaped), for any kind that offers a toggle.
        if raw, kind.previewToggle != nil {
            guard let text = readText(url) else { return unreadable(url) }
            return .html(Self.document(title: url.lastPathComponent,
                                       body: "<pre><code>\(Self.escape(text))</code></pre>"))
        }

        switch kind {
        case .markdown:
            guard let text = readText(url) else { return unreadable(url) }
            let body = Self.inlineLocalImages(in: markdown.html(from: text), baseDir: baseDir)
            return .html(Self.document(title: url.lastPathComponent, body: body))

        case .html:
            guard let text = readText(url) else { return unreadable(url) }
            // Full HTML documents are wrapped too, so our base styles still apply as a fallback;
            // the file's own <head>/<style> (if any) take precedence in the cascade.
            let body = Self.inlineLocalImages(in: text, baseDir: baseDir)
            return .html(Self.document(title: url.lastPathComponent, body: body))

        case .image, .svg:
            // SVG renders as an image (its raw "Code" view is handled above).
            let name = url.lastPathComponent
            let src = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let imgBody = "<div class=\"nativemd-image-page\"><img src=\"\(src)\" alt=\"\(Self.escape(name))\"></div>"
            return .html(Self.document(title: name, body: Self.inlineLocalImages(in: imgBody, baseDir: baseDir)))

        case .pdf:
            return .loadFile(url)

        case .csv:
            guard let text = readText(url) else { return unreadable(url) }
            let delimiter: Character = url.pathExtension.lowercased() == "tsv" ? "\t" : ","
            let rows = DelimitedText.parse(text, delimiter: delimiter)
            return .html(Self.document(title: url.lastPathComponent, body: Self.table(from: rows)))

        case .json:
            guard let text = readText(url) else { return unreadable(url) }
            let pretty = Self.prettyJSON(text) ?? text
            return .html(Self.document(title: url.lastPathComponent, body: "<pre><code>\(Self.escape(pretty))</code></pre>"))

        case .xml:
            guard let text = readText(url) else { return unreadable(url) }
            let pretty = Self.prettyXML(text) ?? text
            return .html(Self.document(title: url.lastPathComponent, body: "<pre><code>\(Self.escape(pretty))</code></pre>"))

        case .text:
            guard let text = readText(url) else { return unreadable(url) }
            return .html(Self.document(title: url.lastPathComponent, body: "<pre><code>\(Self.escape(text))</code></pre>"))

        case .other:
            return .empty("No preview available for \(url.lastPathComponent)")
        }
    }

    /// Render parsed delimited rows as an HTML table (first row treated as the header).
    static func table(from rows: [[String]]) -> String {
        guard let header = rows.first else { return "<p>(empty)</p>" }
        var html = "<table><thead><tr>"
        html += header.map { "<th>\(escape($0))</th>" }.joined()
        html += "</tr></thead><tbody>"
        for row in rows.dropFirst() {
            html += "<tr>" + row.map { "<td>\(escape($0))</td>" }.joined() + "</tr>"
        }
        html += "</tbody></table>"
        return html
    }

    /// Pretty-print JSON (sorted keys), or nil if the text isn't valid JSON.
    static func prettyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        else { return nil }
        return String(data: out, encoding: .utf8)
    }

    /// Pretty-print XML/plist with indentation, or nil if it doesn't parse.
    static func prettyXML(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let doc = try? XMLDocument(data: data, options: [.nodePreserveWhitespace])
        else { return nil }
        return String(data: doc.xmlData(options: [.nodePrettyPrint]), encoding: .utf8)
    }

    // MARK: - Pure helpers (testable without disk)

    /// Strict Content-Security-Policy injected into every preview document.
    ///
    /// Folio runs untrusted file contents (a markdown file may come from anywhere on disk).
    /// JS stays enabled so interactive HTML (charts, calculators, prototypes) still works,
    /// but every network-bound exfiltration channel is closed:
    /// `connect-src 'none'` blocks fetch/XHR/sendBeacon; `img-src data: file:` blocks
    /// `<img src="https://attacker">`; `form-action 'none'` blocks form-POST exfil; the
    /// `default-src 'none'` floor blocks remote scripts/stylesheets/fonts; `base-uri 'none'`
    /// blocks `<base>` URL hijacking. JS-driven navigation away to a remote URL is blocked
    /// at a different layer (`LinkPolicy` in the WKNavigationDelegate).
    public static let contentSecurityPolicy =
        "default-src 'none'; " +
        "img-src data: file:; " +
        "style-src 'unsafe-inline'; " +
        "script-src 'unsafe-inline'; " +
        "connect-src 'none'; " +
        "form-action 'none'; " +
        "base-uri 'none';"

    /// Wrap an HTML `body` fragment in a full document with the embedded stylesheet.
    public static func document(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>\(Styles.css)</style>
        </head>
        <body>
        \(body)
        <script>\(copyButtonScript)</script>
        </body>
        </html>
        """
    }

    /// Replace `src="…"` references to local image files with self-contained base64 `data:` URIs.
    /// WKWebView's `loadHTMLString` cannot load `file://` subresources, so inlining is the
    /// reliable way to show images (whether selected directly or embedded in Markdown/HTML).
    /// Remote (`http(s)`), protocol-relative, and existing `data:` URLs are left untouched.
    public static func inlineLocalImages(in html: String, baseDir: URL) -> String {
        guard let regex = try? NSRegularExpression(pattern: "src=\"([^\"]*)\"") else { return html }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var result = html as NSString

        // Replace from the end so earlier match ranges stay valid as we mutate.
        for match in matches.reversed() {
            guard let srcRange = Range(match.range(at: 1), in: html) else { continue }
            let src = String(html[srcRange])
            let lower = src.lowercased()
            if lower.hasPrefix("data:") || lower.hasPrefix("http://") ||
               lower.hasPrefix("https://") || lower.hasPrefix("//") { continue }

            let decoded = src.removingPercentEncoding ?? src
            let fileURL: URL
            if decoded.hasPrefix("/") {
                fileURL = URL(fileURLWithPath: decoded)
            } else if decoded.hasPrefix("file:"), let u = URL(string: decoded) {
                fileURL = u
            } else {
                fileURL = baseDir.appendingPathComponent(decoded)
            }

            let fileKind = FileKind(for: fileURL)
            guard fileKind == .image || fileKind == .svg,
                  let data = try? Data(contentsOf: fileURL) else { continue }

            let uri = "data:\(imageMimeType(for: fileURL));base64,\(data.base64EncodedString())"
            result = result.replacingCharacters(in: match.range(at: 0), with: "src=\"\(uri)\"") as NSString
        }
        return result as String
    }

    /// MIME type for an image file, by extension.
    public static func imageMimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "tiff", "tif": return "image/tiff"
        case "heic": return "image/heic"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }

    /// JS that adds a "Copy" button to every `<pre>` block, using the clipboard API.
    private static let copyButtonScript = """
    document.addEventListener('DOMContentLoaded', function () {
      document.querySelectorAll('pre').forEach(function (pre) {
        var btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = 'Copy';
        btn.addEventListener('click', function () {
          var code = pre.innerText;
          navigator.clipboard.writeText(code).then(function () {
            btn.textContent = 'Copied';
            setTimeout(function () { btn.textContent = 'Copy'; }, 1200);
          });
        });
        pre.appendChild(btn);
      });
    });
    """

    /// Escape the five HTML-significant characters for safe inclusion in markup/text.
    public static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: - Private

    private func readText(_ url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        // Fall back to a lenient decoding so latin-1 / mixed files still display.
        if let data = try? Data(contentsOf: url) {
            return String(decoding: data, as: UTF8.self)
        }
        return nil
    }

    private func unreadable(_ url: URL) -> PreviewContent {
        .empty("Could not read \(url.lastPathComponent)")
    }
}
