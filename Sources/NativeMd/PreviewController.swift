import SwiftUI
import WebKit
import NativeMdCore

/// Bridges SwiftUI controls (zoom, find bar, menu commands) to the live WKWebView,
/// which is registered by `PreviewPane` once it is created.
@MainActor
final class PreviewController: ObservableObject {
    weak var webView: WKWebView?

    @Published var zoom: Double = PreviewZoom.defaultValue {
        didSet { webView?.pageZoom = zoom }
    }

    // Find bar state.
    @Published var findVisible = false
    @Published var findText = ""

    func zoomIn()    { zoom = PreviewZoom.zoomedIn(zoom) }
    func zoomOut()   { zoom = PreviewZoom.zoomedOut(zoom) }
    func zoomReset() { zoom = PreviewZoom.defaultValue }

    func applyZoom() { webView?.pageZoom = zoom }

    // MARK: - Find in page

    func toggleFind() {
        findVisible.toggle()
        if !findVisible { clearFindHighlight() }
    }

    func find(forward: Bool) {
        guard let webView, !findText.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView.find(findText, configuration: config) { _ in }
    }

    func endFind() {
        findVisible = false
        clearFindHighlight()
    }

    private func clearFindHighlight() {
        webView?.evaluateJavaScript("window.getSelection().removeAllRanges();", completionHandler: nil)
    }
}
