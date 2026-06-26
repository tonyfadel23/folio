import Foundation
import FolioCore

private func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("folio-search-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func write(_ contents: String, to dir: URL, named name: String) -> URL {
    let url = dir.appendingPathComponent(name)
    try? contents.write(to: url, atomically: true, encoding: .utf8)
    return url
}

func runFileSearchTests() {
    let dir = tempDir()

    T.test("query shorter than 2 characters returns no results") {
        let url = write("hello world", to: dir, named: "a.md")
        T.equal(FileSearch.search(query: "h", in: [url]).count, 0)
        T.equal(FileSearch.search(query: "", in: [url]).count, 0)
        T.equal(FileSearch.search(query: "  ", in: [url]).count, 0)
    }

    T.test("matches are case-insensitive") {
        let url = write("Hello World\nHELLO again\nlowercase hello", to: dir, named: "case.md")
        let results = FileSearch.search(query: "hello", in: [url])
        T.equal(results.count, 1)
        T.equal(results[0].hits.count, 3)
    }

    T.test("hits include 1-based line numbers and full line text") {
        let url = write("first line\nsecond match here\nthird line\nfourth match too", to: dir, named: "lines.md")
        let results = FileSearch.search(query: "match", in: [url])
        T.equal(results.count, 1)
        T.equal(results[0].hits.count, 2)
        T.equal(results[0].hits[0].line, 2)
        T.equal(results[0].hits[0].text, "second match here")
        T.equal(results[0].hits[1].line, 4)
        T.equal(results[0].hits[1].text, "fourth match too")
    }

    T.test("per-file hit cap stops after the requested number") {
        // 10 lines each containing the needle; cap at 3 → only 3 hits returned.
        let body = (1...10).map { "line \($0) needle here" }.joined(separator: "\n")
        let url = write(body, to: dir, named: "many.md")
        let results = FileSearch.search(query: "needle", in: [url], maxHitsPerFile: 3)
        T.equal(results[0].hits.count, 3)
        // First three lines should be the ones returned (search reads top-to-bottom).
        T.equal(results[0].hits.map(\.line), [1, 2, 3])
    }

    T.test("results sort by hit count descending, then alphabetically") {
        let a = write("alpha alpha alpha", to: dir, named: "a.md")   // 1 line, 1 hit
        let b = write("alpha\nalpha\nalpha", to: dir, named: "b.md") // 3 hits
        let c = write("alpha\nalpha", to: dir, named: "c.md")        // 2 hits
        let results = FileSearch.search(query: "alpha", in: [a, b, c])
        T.equal(results.map { $0.url.lastPathComponent }, ["b.md", "c.md", "a.md"])
    }

    T.test("no match in any file returns empty results") {
        let url = write("nothing interesting here", to: dir, named: "miss.md")
        T.equal(FileSearch.search(query: "xyzzy", in: [url]).count, 0)
    }

    T.test("files larger than the byte cap are skipped") {
        // 2 KB file with the needle; cap at 1 KB → skipped.
        let big = String(repeating: "padding ", count: 256) + "secret marker"
        let url = write(big, to: dir, named: "big.txt")
        let results = FileSearch.search(query: "secret", in: [url], maxFileBytes: 1024)
        T.equal(results.count, 0)
    }

    T.test("non-readable URL is skipped silently") {
        let bogus = dir.appendingPathComponent("does-not-exist.md")
        T.equal(FileSearch.search(query: "anything", in: [bogus]).count, 0)
    }

    T.test("matchRange locates the needle in original-case line text") {
        let line = "Hello World"
        let range = FileSearch.matchRange(of: "world", in: line)
        T.expect(range != nil, "expected to find 'world' in 'Hello World'")
        if let r = range {
            T.equal(String(line[r]), "World")  // matched range preserves original case
        }
    }

    T.test("total-hit cap stops the scan across files") {
        let a = write((1...5).map { "needle \($0)" }.joined(separator: "\n"), to: dir, named: "ta.md")
        let b = write((1...5).map { "needle \($0)" }.joined(separator: "\n"), to: dir, named: "tb.md")
        let c = write((1...5).map { "needle \($0)" }.joined(separator: "\n"), to: dir, named: "tc.md")
        let results = FileSearch.search(query: "needle", in: [a, b, c], maxHitsPerFile: 5, maxTotalHits: 7)
        let total = results.reduce(0) { $0 + $1.hits.count }
        T.expect(total <= 7 + 5, "total hits should respect maxTotalHits (with at most one trailing per-file overshoot)")
    }
}
