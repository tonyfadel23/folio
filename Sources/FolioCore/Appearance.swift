import Foundation

/// User-facing appearance choice for both the AppKit chrome and the preview pane's CSS.
/// `system` follows macOS; `light` / `dark` override regardless of the system setting.
public enum Appearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    /// CSS class applied to the preview document's `<body>`. The stylesheet keys its theme
    /// off this class so each preview renders in the user's chosen appearance — and falls
    /// back to `prefers-color-scheme` only when the class is `theme-system`.
    public var cssBodyClass: String {
        switch self {
        case .system: return "theme-system"
        case .light:  return "theme-light"
        case .dark:   return "theme-dark"
        }
    }

    /// Human-readable label for the Settings picker.
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
