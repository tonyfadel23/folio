import Foundation

/// What the preview webview should do with a navigation.
public enum LinkDecision: Equatable, Sendable {
    /// Hand the URL to the system (default browser / mail client) and cancel in-webview navigation.
    case openExternally
    /// Let the webview navigate to the URL itself (local files, in-page anchors, initial load).
    case allowInWebView
}

/// Pure decision logic for how the preview pane handles a navigation, kept separate
/// from the WKWebView delegate so it can be tested without a GUI.
public enum LinkPolicy {
    /// Schemes that should be handed off to the system rather than rendered in-pane.
    private static let externalSchemes: Set<String> = ["http", "https", "mailto", "tel", "ftp"]

    /// - Parameters:
    ///   - url: the navigation target.
    ///   - isLinkActivation: true when the navigation was caused by the user clicking a link.
    public static func decide(for url: URL, isLinkActivation: Bool) -> LinkDecision {
        guard isLinkActivation else { return .allowInWebView }
        let scheme = url.scheme?.lowercased() ?? ""
        return externalSchemes.contains(scheme) ? .openExternally : .allowInWebView
    }
}
