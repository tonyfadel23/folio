import Foundation
import FolioCore

/// Drives the "Check for Updates" UI in the Settings popover. Hits GitHub's latest-release
/// endpoint when the user clicks the button — never on launch, never in the background.
/// State is observable so the popover can swap between idle / spinner / result / error.
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case result(UpdateCheck.Status)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// Public for the rare future use of pointing this at a fork; default targets the upstream Folio.
    static let endpoint = URL(string: "https://api.github.com/repos/tonyfadel23/folio/releases/latest")!

    /// Fetch the latest release from GitHub and compare with `current`. The button is hidden
    /// during the in-flight call (see SidebarView), so this method does not coalesce repeat
    /// invocations itself.
    func check(current: String) async {
        state = .checking
        do {
            var request = URLRequest(url: Self.endpoint, timeoutInterval: 8)
            // GitHub recommends a non-empty User-Agent; using the app version is also handy
            // in their logs for anyone correlating client traffic. We send nothing else.
            request.setValue("Folio/\(current) (macOS)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                state = .failed("GitHub returned status \(http.statusCode). Try again later.")
                return
            }

            let release = try JSONDecoder().decode(UpdateCheck.LatestRelease.self, from: data)
            state = .result(UpdateCheck.compare(current: current, latest: release))
        } catch {
            state = .failed("Couldn't reach GitHub. Check your connection and try again.")
        }
    }
}
