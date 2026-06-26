import Foundation

/// A single line-level match within a file's contents.
public struct SearchHit: Equatable, Sendable {
    /// 1-based line number for display ("line 42").
    public let line: Int
    /// The full matching line (untrimmed). UI renders this with the matched
    /// substring emphasized by re-locating `query` inside it case-insensitively.
    public let text: String

    public init(line: Int, text: String) {
        self.line = line
        self.text = text
    }
}

/// All matches within one file, plus its URL for navigation.
public struct SearchResult: Equatable, Sendable, Identifiable {
    public let url: URL
    public let hits: [SearchHit]

    public var id: URL { url }

    public init(url: URL, hits: [SearchHit]) {
        self.url = url
        self.hits = hits
    }
}

/// Pure full-text search over a list of file URLs. Caller is responsible for filtering to
/// text-like files (use `FileKind(for:).isSearchable`) and for running this off the main
/// thread — `FileSearch.search` itself is synchronous so it can be cancelled by the caller
/// via `Task` cancellation between files.
public enum FileSearch {
    /// Default per-file cap: don't drown the UI when a file matches a common word on
    /// hundreds of lines. The UI can show "+ N more" if it wants to.
    public static let defaultMaxHitsPerFile = 5

    /// Default total cap across all results. Stops the scan once reached so a very common
    /// query in a huge folder doesn't render thousands of rows.
    public static let defaultMaxTotalHits = 200

    /// Default per-file byte cap. Files larger than this are skipped (assumed to be a
    /// generated log, a minified bundle, or a misclassified binary).
    public static let defaultMaxFileBytes = 1_048_576  // 1 MiB

    /// Search each URL in `urls` for case-insensitive substring `query`. Returns one
    /// `SearchResult` per file that had at least one hit, sorted by hit count descending
    /// (then by filename for stability).
    ///
    /// - Returns: empty array when `query` (trimmed) is shorter than 2 characters — typing
    ///   a single letter would return matches across most files and isn't useful.
    public static func search(
        query: String,
        in urls: [URL],
        maxHitsPerFile: Int = defaultMaxHitsPerFile,
        maxTotalHits: Int = defaultMaxTotalHits,
        maxFileBytes: Int = defaultMaxFileBytes
    ) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let needle = trimmed.lowercased()

        var results: [SearchResult] = []
        var totalHits = 0

        for url in urls {
            // Size-guard before reading: skips multi-MB files cheaply via stat.
            if let size = fileSize(of: url), size > maxFileBytes { continue }
            guard let text = readText(at: url) else { continue }

            let hits = matchLines(in: text, needle: needle, maxHits: maxHitsPerFile)
            if !hits.isEmpty {
                results.append(SearchResult(url: url, hits: hits))
                totalHits += hits.count
                if totalHits >= maxTotalHits { break }
            }
        }

        // Files with more hits first (stronger signal that the file is "about" the query),
        // then alphabetical for predictable ordering on ties.
        results.sort { lhs, rhs in
            if lhs.hits.count != rhs.hits.count { return lhs.hits.count > rhs.hits.count }
            return lhs.url.lastPathComponent.localizedCaseInsensitiveCompare(rhs.url.lastPathComponent) == .orderedAscending
        }

        return results
    }

    /// Locate `needle` inside `lineText` case-insensitively and return the range over the
    /// *original-case* string. Returns nil if no match. Exposed for the UI to highlight
    /// the matched portion without re-implementing the lookup.
    public static func matchRange(of needle: String, in lineText: String) -> Range<String.Index>? {
        lineText.range(of: needle, options: .caseInsensitive)
    }

    // MARK: - Private

    private static func matchLines(in text: String, needle: String, maxHits: Int) -> [SearchHit] {
        var hits: [SearchHit] = []
        var lineNumber = 0
        text.enumerateLines { line, stop in
            lineNumber += 1
            if line.range(of: needle, options: .caseInsensitive) != nil {
                hits.append(SearchHit(line: lineNumber, text: line))
                if hits.count >= maxHits { stop = true }
            }
        }
        return hits
    }

    private static func readText(at url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        // Latin-1 fallback for files with mixed/unknown encoding (e.g. legacy text files).
        if let data = try? Data(contentsOf: url) {
            return String(data: data, encoding: .isoLatin1)
        }
        return nil
    }

    private static func fileSize(of url: URL) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
    }
}
