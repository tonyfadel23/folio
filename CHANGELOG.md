# Changelog

All notable changes to Folio are documented in this file. Versioning follows
[Semantic Versioning](https://semver.org/).

## [1.7.0] — 2026-06-26

Full-text search across the open folder.

- **Search inside files, not just filenames.** Typing in the sidebar search box now finds matches *inside* every text-like file in the folder (markdown, html, json/xml/csv, source code, plain text). Results appear under "In files (N matches in M files)" alongside the existing "Files (N)" name matches.
- **Each hit is one row** with the 1-based line number, the matching line text (trimmed), and the matched substring bolded. Click a hit to open the file in the preview; press ⌘F to jump to the exact location.
- **Sorted by relevance.** Files with more matches surface first (stronger signal that the file is "about" the query), with alphabetical tiebreak.
- **Bounded to stay fast.** Per-file cap of 5 hits, total cap of 200 matches across all results, per-file byte cap of 1 MiB (skips multi-MB logs and minified bundles). Reads happen off-main; a new keystroke cancels the in-flight task so the sidebar is responsive even on big folders.
- **Architecture.** Pure search logic in `FolioCore.FileSearch` (sync, testable, no UI deps); `AppModel.performTextSearch(_:)` owns the async orchestration + cancellation; `SidebarView` renders the hits. `FileKind.isSearchable` decides which files to scan, so binary kinds (image, pdf, svg) are skipped before any I/O.

[1.7.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.7.0

## [1.6.1] — 2026-06-23

Bug fix: Markdown previews no longer render YAML frontmatter as raw text.

- **Strip YAML frontmatter on render.** Files from Jekyll, Hugo, Astro, Obsidian, Claude Code skills, and similar tools start with a `---` block of metadata. Previously this rendered as a horizontal rule + a wall of `key: value` paragraphs at the top of the preview, drowning the actual content. `MarkdownRenderer` now detects the leading `---\n…\n---\n` pattern and strips it before parsing. A lone `---` on line 1 with no matching close is still treated as a thematic break (preserves standard markdown semantics). The Raw toggle continues to show the full source including the frontmatter, for power users who need to inspect or copy the YAML.

[1.6.1]: https://github.com/tonyfadel23/folio/releases/tag/v1.6.1

## [1.6.0] — 2026-06-23

Open files directly, render real-world HTML, and stop forcing user HTML into Folio's dark theme.

- **Default-app support.** Folio now declares document types (`CFBundleDocumentTypes` + a Markdown UTI) for Markdown, HTML, text/source, JSON/XML/CSV, images, PDF, and folders. You can set it as the default opener for `.md` and friends in Finder → Get Info → "Open with". Double-clicking a file (or `open -a Folio file.md`, or dragging onto the Dock icon) opens its enclosing folder in the sidebar with that file selected — handled via `NSApplicationDelegate.application(_:open:)` → `AppModel.open(fileOrFolder:)`.
- **Looser preview sandbox.** The preview's Content-Security-Policy was relaxed from a strict no-network floor to a permissive, browser-like policy: scripts, styles, web fonts, images, frames, and `fetch`/XHR now load from any source (incl. inline + `eval`), and `<iframe>` embeds are allowed to load. Pages that pull in CDN scripts (Tailwind, jQuery, charting libs) or remote assets render correctly instead of breaking. Top-level link clicks still open in your default browser via `LinkPolicy`. **Trade-off:** a previewed file can now reach the network — preview only files you trust.
- **HTML preview no longer inherits the app theme.** Previously, if Folio was in Dark mode the wrapper imposed a dark background on every previewed HTML file, inverting websites' light designs. HTML previews now use a neutral light wrapper regardless of the app's appearance, letting the page's own CSS (and any `@media (prefers-color-scheme)` rules) win — matching what a browser would do. Markdown and other Folio-rendered previews still honor the user's chosen theme.

[1.6.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.6.0

## [1.5.0] — 2026-06-21

UX polish: more visible copy feedback, and the raw/rendered toggle is now per-file.

- **Copy toast.** Clicking the "Copy" button on a code block now also shows a centered toast at the top of the preview (in addition to the in-place "Copied" label flicker). Long code blocks scroll the button off-screen — the toast guarantees the user always sees the confirmation. Auto-dismisses after ~1.4s. Dark-mode toast lifts the background so it stays visible against the dark page.
- **Per-file raw / rendered.** The Formatted ↔ Raw picker now remembers its state per file. In tab mode: flip a file to Raw, switch to another tab, switch back — your Raw choice is preserved. In single mode: same — every file remembers its own toggle until you close the folder.
- **State storage.** Added `AppModel.rawStates: [URL: Bool]`, keyed by file URL. Cleared on folder change (so new folders start fresh) and pruned per-tab on `closeTab` (so the map stays bounded).
- **Settings persistence (no change, just confirmed).** Appearance, tab mode, and show-hidden are already persisted to `~/Library/Preferences/com.tonyfadel.folio.plist` via UserDefaults and restored in `AppModel.init`. If you see resets during local dev, that's `cfprefsd` caching — `killall cfprefsd` flushes it. Brew-installed users don't see this.

[1.5.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.5.0

## [1.4.0] — 2026-06-21

In-app update check.

- New **"Check for Updates"** button in the Settings popover (alongside the version number). Click it to query GitHub for the latest release and compare it against the running build.
- Three outcomes:
  - **Up to date** → green checkmark + "You're on the latest version."
  - **Update available** → blue arrow + "vX.Y.Z is available." + a **View** button that opens the release page in the user's default browser. From there the user can read the release notes and either `brew upgrade --cask folio` or download the DMG.
  - **Dev build** (running newer than the latest release) → hammer icon + "Dev build (latest released: vX.Y.Z)" — useful when running from `swift run` or a local build.
- Never auto-checks. Only contacts GitHub when the user clicks the button. The HTTPS request includes only a generic `User-Agent` (the app version) — no telemetry, no analytics.
- Pure version-comparison + JSON decoding logic lives in `FolioCore.UpdateCheck` (testable, network-free); the URLSession call + UI live in the `Folio` target.

[1.4.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.4.0

## [1.3.0] — 2026-06-21

Two new Settings: appearance (Light / Dark / System) and tab mode.

### Appearance
- New picker in Settings: Light / Dark / **System** (defaults to Dark on first install).
- Affects both the AppKit chrome (`NSApp.appearance`) and the preview pane in lockstep.
- Preview CSS refactored to CSS custom properties keyed off body classes (`body.theme-dark`, `body.theme-light`, and `@media (prefers-color-scheme: dark) body.theme-system`). Colors are defined once per theme; every rule reads via `var(--*)`.
- The currently-open preview re-renders with the new theme as soon as the picker changes (via `reloadToken`).

### Tab mode
- New picker in Settings: **One at a time** (default; the existing single-preview behavior) or **In tabs**.
- In tabs mode, clicking a file in the sidebar opens a new tab. Re-clicking an already-open file activates its existing tab (no duplicates).
- Tab bar appears above the preview when at least one tab is open. Each tab shows the file's icon + name + close button.
- Closing the active tab activates the neighboring tab (right-leaning), or clears the preview if it was the last.
- Opening a new folder clears all tabs. Switching back to single mode collapses to the currently-active file. Tabs whose files disappear (rename/move/delete) are removed automatically.
- No keyboard shortcuts in this release; deferred to a follow-up.

[1.3.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.3.0

## [1.2.2] — 2026-06-21 (security)

Hardens the preview pane against malicious file contents while preserving JavaScript for interactive HTML (charts, prototypes, calculators).

- Inject strict Content-Security-Policy into every preview document: `default-src 'none'; connect-src 'none'; form-action 'none'; base-uri 'none'; img-src data: file:; style-src 'unsafe-inline'; script-src 'unsafe-inline'`. This blocks every network-bound exfiltration channel (`fetch`, external `<img>`, external `<form>`, external `<style>`, external `<script>`) without disabling client-side interactivity.
- Tighten `LinkPolicy`: `javascript:` and `data:` link clicks are now denied outright (previously rendered in-pane). Non-click navigations to `http(s)` are also denied, closing the silent exfiltration path that `<meta http-equiv="refresh">`, `window.open`, and JS-driven `document.location` changes would otherwise have used.
- Add a third `LinkDecision.deny` case to `LinkPolicy` and route it through `PreviewPane.Coordinator` as `decisionHandler(.cancel)`.
- Add `LinkPolicyTests` coverage for `javascript:`, `data:`, and meta-refresh-style non-click navigation.

Reference: findings from the in-session security review covering `Sources/FolioCore/PreviewHTML.swift` and `Sources/FolioCore/LinkPolicy.swift`. Residual risk: a malicious preview file can still render in-pane phishing UI; clicks on such UI route through the strict link policy (denied, or opened in the user's actual browser where they have context to evaluate).

[1.2.2]: https://github.com/tonyfadel23/folio/releases/tag/v1.2.2

## [1.2.1] — 2026-06-21

Internal cleanup; no user-visible behavior changes.

- Renamed internal Swift targets `NativeMd`/`NativeMdCore`/`NativeMdTests` to `Folio`/`FolioCore`/`FolioTests` (the historical `NativeMd` was the pre-rebrand name).
- Renamed bundle identifier from `com.tony.nativemd` to `com.tonyfadel.folio`.
- Renamed `UserDefaults` keys from `NativeMd.*` to `Folio.*`.
- Fixed `scripts/run.sh` (was trying to `open NativeMd.app`, which `bundle.sh` hadn't produced since the user-facing rename).

[1.2.1]: https://github.com/tonyfadel23/folio/releases/tag/v1.2.1

## [1.2.0] — 2026-06-21

First public release.

- Native macOS file browser + previewer (SwiftUI + WKWebView)
- Markdown, HTML, image, PDF, source-code, CSV/TSV/JSON/XML previews
- Format toggle (Formatted/Raw, Website/Code, Table/Raw, Pretty/Raw, Image/Code)
- Live auto-reload via FSEvents
- Right-click menu: Reveal in Finder, Open in Default App, Copy Path,
  Copy as Rich Text, Rename, Move to Trash
- Drag-and-drop file/folder moves in the sidebar
- Search, zoom, find-in-page (⌘F)
- Universal binary (arm64 + x86_64), no runtime dependencies
- Released under the MIT License

[1.2.0]: https://github.com/tonyfadel23/folio/releases/tag/v1.2.0
