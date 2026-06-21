import SwiftUI
import WebKit
import AppKit
import FolioCore

/// Right pane: renders the selected file via a single WKWebView.
/// `reloadToken` forces a re-render (used by live reload) even when the file URL is unchanged.
struct PreviewPane: NSViewRepresentable {
    let file: FileNode?
    let reloadToken: Int
    let raw: Bool
    let controller: PreviewController

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true // trackpad pinch-to-zoom for all content
        webView.setValue(false, forKey: "drawsBackground") // let CSS control the background
        context.coordinator.webView = webView
        controller.webView = webView
        webView.pageZoom = controller.zoom
        context.coordinator.render(file, token: reloadToken, raw: raw)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        controller.webView = webView
        webView.pageZoom = controller.zoom
        context.coordinator.render(file, token: reloadToken, raw: raw)
    }

    /// Owns the webview, loads content, and applies `LinkPolicy` to navigations.
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private let builder = PreviewHTML()
        private var lastLoaded: URL?
        private var lastToken: Int = -1
        private var lastRaw = false

        func render(_ file: FileNode?, token: Int, raw: Bool) {
            guard let webView else { return }

            guard let file, !file.isDirectory else {
                if lastLoaded != nil || lastToken != token { loadPlaceholder("Select a file to preview") }
                lastLoaded = nil
                lastToken = token
                return
            }
            // Re-render if the file changed, the reload token advanced, or the raw/rendered mode flipped.
            if lastLoaded == file.url && lastToken == token && lastRaw == raw { return }
            lastLoaded = file.url
            lastToken = token
            lastRaw = raw

            let baseURL = file.url.deletingLastPathComponent()
            switch builder.build(for: file.url, raw: raw) {
            case .html(let html):
                webView.loadHTMLString(html, baseURL: baseURL)
            case .loadFile(let url):
                webView.loadFileURL(url, allowingReadAccessTo: baseURL)
            case .empty(let message):
                loadPlaceholder(message)
            }
        }

        private func loadPlaceholder(_ message: String) {
            let body = "<div class=\"nativemd-placeholder\">\(PreviewHTML.escape(message))</div>"
            webView?.loadHTMLString(PreviewHTML.document(title: "Folio", body: body), baseURL: nil)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let isLink = navigationAction.navigationType == .linkActivated
            if let url = navigationAction.request.url {
                switch LinkPolicy.decide(for: url, isLinkActivation: isLink) {
                case .openExternally:
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                case .allowInWebView:
                    break
                }
            }
            decisionHandler(.allow)
        }
    }
}
