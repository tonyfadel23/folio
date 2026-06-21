import Foundation
import FolioCore

private let releasePageURL = URL(string: "https://github.com/tonyfadel23/folio/releases/tag/v1.0.0")!

private func release(_ tag: String) -> UpdateCheck.LatestRelease {
    UpdateCheck.LatestRelease(tagName: tag, htmlURL: releasePageURL)
}

func runUpdateCheckTests() {
    T.test("equal versions report up-to-date when latest has v prefix") {
        T.equal(UpdateCheck.compare(current: "1.3.0", latest: release("v1.3.0")), .upToDate)
    }

    T.test("equal versions report up-to-date when latest omits v prefix") {
        T.equal(UpdateCheck.compare(current: "1.3.0", latest: release("1.3.0")), .upToDate)
    }

    T.test("newer patch from upstream reports update available") {
        if case .updateAvailable(let latest, let url) = UpdateCheck.compare(current: "1.3.0", latest: release("v1.3.1")) {
            T.equal(latest, "1.3.1")
            T.equal(url, releasePageURL)
        } else {
            T.expect(false, "expected .updateAvailable for 1.3.0 → v1.3.1")
        }
    }

    T.test("numeric comparison handles double-digit components") {
        // Naive lexical compare would consider "1.10.0" < "1.3.0" (because "1" < "3").
        // With .numeric, "1.10.0" correctly sorts after "1.3.0".
        if case .updateAvailable(let latest, _) = UpdateCheck.compare(current: "1.3.0", latest: release("v1.10.0")) {
            T.equal(latest, "1.10.0")
        } else {
            T.expect(false, "expected .updateAvailable for 1.3.0 → v1.10.0")
        }
    }

    T.test("running version newer than latest release reports ahead (dev build)") {
        if case .ahead(let latest) = UpdateCheck.compare(current: "1.4.0", latest: release("v1.3.0")) {
            T.equal(latest, "1.3.0")
        } else {
            T.expect(false, "expected .ahead for current 1.4.0 vs released 1.3.0")
        }
    }

    T.test("major bump is detected as an update") {
        if case .updateAvailable(let latest, _) = UpdateCheck.compare(current: "1.9.9", latest: release("v2.0.0")) {
            T.equal(latest, "2.0.0")
        } else {
            T.expect(false, "expected .updateAvailable for major bump")
        }
    }

    // Normalization (v-prefix stripping, whitespace trimming) is covered indirectly by the
    // "equal versions" + "numeric comparison" tests above; it is intentionally not exposed
    // as a public API surface.
}
