# Folio

[![CI](https://github.com/tonyfadel23/folio/actions/workflows/ci.yml/badge.svg)](https://github.com/tonyfadel23/folio/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/tonyfadel23/folio)](https://github.com/tonyfadel23/folio/releases/latest)

A super lightweight **native macOS file browser + previewer**. Open a folder and its files
and subfolders show as an expandable tree on the left; select a file and it previews on the
right. Or double-click a single `.md`/`.html`/image/PDF in Finder and Folio opens straight to
it — [set it as your default viewer](#set-folio-as-your-default-viewer) and it replaces Quick
Look for the files you actually read.

- **Markdown** → rendered as nicely-styled HTML (incl. tables, strikethrough, task-list checkboxes, and a copy button on code blocks)
- **HTML** → shown as a live web page (CDN scripts, web fonts, remote images, and `<iframe>` embeds all load); external links open in your default browser
- **Images** (png/jpg/gif/svg/webp/…) → shown inline
- **PDF** → rendered natively
- **Text / source code** → shown as styled, escaped text
- **Search box** → type to filter; matches show as a flat list with their folder paths
- **Live auto-reload** → edits on disk re-render the preview automatically (FSEvents); files added/removed update the tree without collapsing it
- **Right-click menu** → Reveal in Finder, Open in Default App, Open Enclosing Folder, Copy Path, **Copy as Rich Text** (Markdown/HTML → paste formatted into Google Docs/Word/Pages), Rename…, Move to Trash (with confirmation)
- **Drag & drop** → drag a file or folder onto another folder in the sidebar to move it
- **Zoom & Find** → `⌘+` / `⌘-` / `⌘0` zoom the preview; `⌘F` finds within the rendered page
- **Handles large folders** → bounded, off-main loading with a spinner; warns if a folder is too big to show fully
- **Settings** (gear in the toolbar) → app version and a **Show hidden files & folders** toggle; hidden items appear dimmed
- **Format toggle** (right side of the title bar) → switch the selected file between rendered and source:
  Markdown **Formatted/Raw**, HTML **Website/Code**, CSV/TSV **Table/Raw**, JSON **Pretty/Raw**, XML/plist **Formatted/Raw**, SVG **Image/Code**
- **Pinch-to-zoom** → trackpad pinch zooms any preview (images, web, docs); ⌘+/−/0 also work
- **Open files directly** → set Folio as the default app for `.md`, `.html`, images, PDF, and more (Finder → Get Info → "Open with"); double-click a file, `open -a Folio file.md`, or drag onto the Dock icon to open its folder with the file selected
- **Remembers** the last folder, the last file you viewed, and the window size/position
- Light & dark mode aware

Built with SwiftUI + WKWebView. The release `.app` is ~0.5 MB and has **no runtime dependencies**
(the only library, [Ink](https://github.com/JohnSundell/Ink) for Markdown, is statically linked).

## Install

Three install options. **Build from source is the smoothest path on modern macOS** (no Gatekeeper friction) — see [why](#why-build-from-source-is-smoothest).

### Build from source — recommended

Folio is small and builds in under a minute. Requires only Swift 6 (Command Line Tools, no full Xcode), pre-installed on most Macs.

```bash
git clone https://github.com/tonyfadel23/folio.git
cd folio
bash scripts/run.sh
```

`scripts/run.sh` compiles a universal binary, assembles `Folio.app` in the project root, and launches it. To install it permanently:

```bash
mv Folio.app /Applications/
```

Then double-click from `/Applications` or launch via Spotlight (⌘+Space → "Folio").

**To update later:**

```bash
cd folio
git pull
bash scripts/bundle.sh
mv -f Folio.app /Applications/
```

`bundle.sh` builds without launching; the `-f` on `mv` overwrites the previous install. Folio's in-app "Check for Updates" button (Settings gear → top of popover) tells you when there's a newer tag worth pulling.

### Homebrew

```bash
brew install --cask tonyfadel23/tap/folio
```

Homebrew strips the macOS quarantine attribute. On macOS Sequoia (15)+ and Tahoe, you may still see a one-time *"Apple could not verify"* dialog on first launch — grant trust via **System Settings → Privacy & Security → Open Anyway**, enter your password, confirm. This persists for that signature.

**To update:** `brew update && brew upgrade --cask folio`

### Direct DMG download

Grab the latest `Folio-x.y.z.dmg` from the [Releases page](https://github.com/tonyfadel23/folio/releases/latest), open it, drag **Folio** into your `Applications` folder.

> **Gatekeeper on macOS 14+:** Double-clicking will show *"Apple could not verify 'Folio' is free of malware"* with no "Open" button. Workaround:
>
> 1. Click **Done** on the dialog.
> 2. **System Settings → Privacy & Security**, scroll to the bottom.
> 3. Click **Open Anyway** next to the Folio block message, enter your password, confirm.
>
> On the newest macOS, an unsigned app can be auto-removed by the background malware scanner before you grant trust. If that happens, the **Build from source** path above avoids it entirely.

### Why build from source is smoothest

macOS's Gatekeeper is triggered most aggressively by the `com.apple.quarantine` extended attribute, which is set on any file downloaded from the network. A locally-built `.app` doesn't carry that attribute, so Gatekeeper never sees Folio as "downloaded from the internet" and never invokes the verification flow. Until Folio is notarized with an Apple Developer ID, building locally is the only path with no first-launch friction.

## Set Folio as your default viewer

Folio registers itself as a handler for Markdown, HTML, plain-text/source, JSON, XML, CSV,
images, PDF, and folders, so you can make it the app that opens those files on double-click:

1. In Finder, select a file (e.g. a `.md`), press **⌘I** (Get Info).
2. Under **Open with**, choose **Folio**.
3. Click **Change All…** to apply it to *every* file of that type.

Or from the Terminal:

```bash
# Open one file now (without changing the default)
open -a Folio notes.md

# A folder works too — opens with that folder loaded in the sidebar
open -a Folio ~/Documents/notes
```

Opening a file loads its enclosing folder in the sidebar with the file selected, so you keep
the tree, search, and live-reload — you're not locked into a single-file view. Dragging a file
or folder onto the Folio Dock icon does the same thing.

## Preview sandbox

Folio renders HTML the way a browser does: pages can load CDN scripts, web fonts, remote
images, run JavaScript (including `eval`), use `fetch`/XHR, and embed `<iframe>`s. That's what
makes real-world HTML — Tailwind/jQuery-based pages, charts, interactive prototypes — render
correctly instead of breaking.

The flip side is that **a previewed file can reach the network**, so preview HTML you trust the
same way you'd trust opening it in a browser. Top-level link clicks are still handed off to your
default browser (the preview never navigates itself away to a remote page) — see
`LinkPolicy` in `Sources/FolioCore`. Markdown, text, CSV, JSON, XML, and image previews are
generated by Folio from the file's bytes and don't execute the file as a program.

## Develop

```bash
swift run FolioTests              # run the test suite
bash scripts/run.sh               # build + launch the .app
bash scripts/bundle.sh            # build the .app without launching
bash scripts/make_iconset.sh      # regenerate Resources/AppIcon.icns
```

A `sample/` folder with one of each file type is included for a quick smoke test of the previewer.

## Project layout

```
Sources/
  FolioCore/      # pure, unit-tested logic (no UI)
    FileKind, FileNode (+ matchingFiles),   — tree model + classification + search
    FileTreeLoader
    MarkdownRenderer (Ink), PreviewHTML,    — preview payload building
    Styles, LinkPolicy                      — CSS + external-link routing
  Folio/          # SwiftUI shell
    FolioApp, AppModel, ContentView,
    SidebarView (NavigationSplitView + OutlineGroup + .searchable),
    PreviewPane (WKWebView + WKNavigationDelegate)
  FolioTests/     # standalone test runner (see note below)
Resources/        # AppIcon.icns
scripts/          # bundle.sh, run.sh, make_icon.swift, make_iconset.sh
```

## Testing note

Command Line Tools (without full Xcode) does **not** ship XCTest, so `swift test` cannot run.
Tests are therefore a plain executable target (`FolioTests`) with a tiny assertion harness,
run via `swift run FolioTests` — same TDD workflow, no Xcode needed.

## Releasing

Releases are produced automatically by GitHub Actions when a `v*` tag is pushed:

```bash
# Bump VERSION, then:
git tag vX.Y.Z
git push origin vX.Y.Z
```

This triggers `.github/workflows/release.yml`, which runs the tests, builds the universal DMG via `scripts/make_dmg.sh`, and attaches it to a new GitHub Release with auto-generated notes from the commit log. See [`CHANGELOG.md`](CHANGELOG.md) for prior releases.

## License

Folio is released under the [MIT License](LICENSE). You're free to use, copy, modify, and distribute it — commercially or not — as long as the copyright notice is preserved.

The bundled binary statically links [Ink](https://github.com/JohnSundell/Ink) for Markdown rendering. Ink's MIT license and copyright notice are reproduced in [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) per its terms.

## Acknowledgments

- [Ink](https://github.com/JohnSundell/Ink) by John Sundell — fast, zero-dependency Markdown parser.
