import Foundation

/// App version, read from the bundle's Info.plist (the single source of truth is the
/// `VERSION` file, which `scripts/bundle.sh` stamps into the plist). When running via
/// `swift run` (no bundle), this reports "dev" so it's obvious you're not on a release build.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    /// e.g. "Folio 1.0.0" — what the UI shows.
    static var label: String { "Folio \(version)" }

    /// Title-bar subtitle, e.g. "v1.0.0" (or "dev build" when run unbundled).
    static var subtitle: String { version == "dev" ? "dev build" : "v\(version)" }
}
