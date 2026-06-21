import Foundation

/// Pure update-check helpers: a small Decodable matching GitHub's "latest release" API
/// response, plus version comparison that handles the `v` prefix and multi-digit components
/// correctly. The actual HTTPS fetch lives in the UI layer so this module stays pure +
/// network-free + testable.
public enum UpdateCheck {
    /// Just the fields of `GET /repos/{owner}/{repo}/releases/latest` we care about.
    public struct LatestRelease: Decodable, Sendable, Equatable {
        public let tagName: String
        public let htmlURL: URL

        public init(tagName: String, htmlURL: URL) {
            self.tagName = tagName
            self.htmlURL = htmlURL
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    /// Outcome of comparing the running app's version against the latest release on GitHub.
    public enum Status: Equatable, Sendable {
        case upToDate
        case updateAvailable(latest: String, url: URL)
        /// The running build is *newer* than the latest published release (dev builds, pre-tag).
        case ahead(latest: String)
    }

    /// Compare `current` (e.g. `"1.3.0"`) against `latest`. Both versions are normalized to
    /// strip a leading `v` and trim whitespace; comparison uses `.numeric` so `"1.10.0" > "1.3.0"`.
    public static func compare(current: String, latest: LatestRelease) -> Status {
        let currentN = normalize(current)
        let latestN = normalize(latest.tagName)
        switch currentN.compare(latestN, options: .numeric) {
        case .orderedAscending:  return .updateAvailable(latest: latestN, url: latest.htmlURL)
        case .orderedSame:       return .upToDate
        case .orderedDescending: return .ahead(latest: latestN)
        }
    }

    /// Strip a leading `v` (so `"v1.3.0" == "1.3.0"`) and trim surrounding whitespace.
    /// Internal so tests can verify the normalization rule, but not part of the public surface.
    static func normalize(_ v: String) -> String {
        let trimmed = v.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
    }
}
