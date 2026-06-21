import Foundation
import FolioCore

private func url(_ s: String) -> URL { URL(string: s)! }

func runLinkPolicyTests() {
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
    T.test("non-click navigation always allowed (e.g. initial load)") {
        // Even an http URL should not be hijacked when it is not a user click.
        T.equal(LinkPolicy.decide(for: url("https://example.com"), isLinkActivation: false), .allowInWebView)
    }
}
