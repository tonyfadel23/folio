import Foundation

/// What the preview webview should do with a navigation.
public enum LinkDecision: Equatable, Sendable {
    /// Hand the URL to the system (default browser / mail client) and cancel in-webview navigation.
    case openExternally
    /// Let the webview navigate to the URL itself (initial load, in-page anchors).
    case allowInWebView
    /// Cancel the navigation outright. Used for dangerous schemes (`javascript:`, `data:`) and
    /// for non-click navigations to remote URLs, which would otherwise allow a malicious
    /// previewed file to exfiltrate data via `<meta refresh>`, `window.open`, or JS-driven nav.
    case deny
}

/// Pure decision logic for how the preview pane handles a navigation, kept separate
/// from the WKWebView delegate so it can be tested without a GUI.
public enum LinkPolicy {
    /// Schemes that should be handed off to the system rather than rendered in-pane.
    private static let externalSchemes: Set<String> = ["http", "https", "mailto", "tel", "ftp"]
    /// Schemes safe to navigate to inside the preview (used for initial loads + in-page anchors).
    private static let inPaneSchemes: Set<String> = ["file", "about", ""]

    /// - Parameters:
    ///   - url: the navigation target.
    ///   - isLinkActivation: true when the navigation was caused by the user clicking a link.
    public static func decide(for url: URL, isLinkActivation: Bool) -> LinkDecision {
        let scheme = url.scheme?.lowercased() ?? ""

        // Non-click navigations: WKWebView fires these for the initial load, meta-refresh,
        // iframe loads, JS-driven `location` changes, and `window.open` from script.
        // Allow only schemes WebKit needs to load our own preview content; deny everything else
        // to close the silent-exfiltration channel that scripts and meta-refresh would otherwise use.
        guard isLinkActivation else {
            return inPaneSchemes.contains(scheme) ? .allowInWebView : .deny
        }

        // User clicked a link in the preview.
        if inPaneSchemes.contains(scheme) {
            return .allowInWebView      // in-page anchors, file:// links inside the previewed dir
        }
        if externalSchemes.contains(scheme) {
            return .openExternally      // hand http(s)/mailto/tel/ftp to the user's default app
        }
        return .deny                    // javascript:, data:, and anything else: refuse to dispatch
    }
}
