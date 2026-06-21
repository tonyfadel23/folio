# Changelog

All notable changes to Folio are documented in this file. Versioning follows
[Semantic Versioning](https://semver.org/).

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
