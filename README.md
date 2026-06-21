# Folio

A super lightweight **native macOS file browser + previewer**. Pick a folder on the left;
its files and subfolders show as an expandable tree (always on the left). Select a file and
it previews on the right:

- **Markdown** → rendered as nicely-styled HTML (incl. tables, strikethrough, task-list checkboxes, and a copy button on code blocks)
- **HTML** → shown as a live web page; external links open in your default browser
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
- **Remembers** the last folder, the last file you viewed, and the window size/position
- Light & dark mode aware

> The user-facing app is **Folio**; the internal Swift target/binary is still `NativeMd`.

Built with SwiftUI + WKWebView. The release `.app` is ~0.5 MB and has **no runtime dependencies**
(the only library, [Ink](https://github.com/JohnSundell/Ink) for Markdown, is statically linked).

## Requirements

- macOS 13+
- Swift 6 / Command Line Tools (full Xcode **not** required)

## Build, run, test

```bash
# Run the test suite (pure logic)
swift run NativeMdTests

# Build the app bundle and launch it
bash scripts/run.sh

# Just build the .app without launching
bash scripts/bundle.sh

# Regenerate the app icon (Resources/AppIcon.icns)
bash scripts/make_iconset.sh
```

After `run.sh`, `Folio.app` sits in the project root — double-click it or move it to
`/Applications`. The last opened folder is remembered between launches.

A `sample/` folder with one of each file type is included for a quick smoke test.

## Project layout

```
Sources/
  NativeMdCore/   # pure, unit-tested logic (no UI)
    FileKind, FileNode (+ matchingFiles),   — tree model + classification + search
    FileTreeLoader
    MarkdownRenderer (Ink), PreviewHTML,    — preview payload building
    Styles, LinkPolicy                      — CSS + external-link routing
  NativeMd/       # SwiftUI shell
    NativeMdApp, AppModel, ContentView,
    SidebarView (NavigationSplitView + OutlineGroup + .searchable),
    PreviewPane (WKWebView + WKNavigationDelegate)
  NativeMdTests/  # standalone test runner (see note below)
Resources/        # AppIcon.icns
scripts/          # bundle.sh, run.sh, make_icon.swift, make_iconset.sh
```

## Testing note

Command Line Tools (without full Xcode) does **not** ship XCTest, so `swift test` cannot run.
Tests are therefore a plain executable target (`NativeMdTests`) with a tiny assertion harness,
run via `swift run NativeMdTests` — same TDD workflow, no Xcode needed.
