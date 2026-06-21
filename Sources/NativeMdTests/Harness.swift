import Foundation

/// Minimal test harness — no XCTest (unavailable under Command Line Tools).
/// Tests register themselves and run via `swift run NativeMdTests`.
enum T {
    private(set) static var failures: [String] = []
    private(set) static var checks = 0
    private static var currentTest = "<none>"

    static func test(_ name: String, _ body: () throws -> Void) {
        currentTest = name
        do {
            try body()
            print("  ✓ \(name)")
        } catch {
            record("threw \(error)")
            print("  ✗ \(name) — threw \(error)")
        }
    }

    static func expect(_ condition: Bool, _ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        checks += 1
        if !condition { record("\(message()) [\(file):\(line)]") }
    }

    static func equal<V: Equatable>(_ a: V, _ b: V, file: String = #fileID, line: Int = #line) {
        checks += 1
        if a != b { record("expected \(b), got \(a) [\(file):\(line)]") }
    }

    static func contains(_ haystack: String, _ needle: String, file: String = #fileID, line: Int = #line) {
        checks += 1
        if !haystack.contains(needle) {
            record("expected to contain \"\(needle)\" [\(file):\(line)]")
        }
    }

    private static func record(_ msg: String) {
        failures.append("[\(currentTest)] \(msg)")
    }

    static func summarize() -> Never {
        print("\n\(checks) checks run.")
        if failures.isEmpty {
            print("✅ All tests passed.")
            exit(0)
        } else {
            print("❌ \(failures.count) failure(s):")
            for f in failures { print("   - \(f)") }
            exit(1)
        }
    }
}
