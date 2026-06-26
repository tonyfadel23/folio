import SwiftUI
import AppKit
import FolioCore

/// App-wide state: the loaded folder tree, the current selection, and live-reload plumbing.
@MainActor
final class AppModel: ObservableObject {
    @Published var root: FileNode?
    @Published var isLoading = false
    /// True when the folder was too large and the tree was capped.
    @Published var truncated = false
    /// Bumped whenever the watched folder changes, to force the preview to re-render.
    @Published var reloadToken = 0

    @Published var selection: FileNode? {
        didSet {
            // Remember the last previewed *file* so we can restore it next launch, and record
            // its modification date as the baseline for live-reload comparisons.
            if let sel = selection, !sel.isDirectory {
                UserDefaults.standard.set(sel.url.path, forKey: lastSelectionKey)
                selectedModDate = Self.modificationDate(of: sel.url)
                // In tabs mode, selecting a file (from sidebar or restore) also pins it as a tab.
                // Clicking an existing tab is a no-op here because the file's URL is already present.
                if openInTabs, !openTabs.contains(where: { $0.url == sel.url }) {
                    openTabs.append(sel)
                }
            } else {
                selectedModDate = nil
            }
        }
    }

    /// Whether dotfiles/dot-folders are shown. Persisted; toggling reloads the tree.
    @Published var showHidden: Bool {
        didSet {
            UserDefaults.standard.set(showHidden, forKey: showHiddenKey)
            reloadShowingLoading() // re-scan with a visible loading state (no stale tree flash)
        }
    }

    /// User-facing appearance preference. Drives both `NSApp.appearance` (chrome) and the
    /// CSS body class injected by `PreviewHTML.document(theme:)` (preview pane).
    /// Default = `.dark` on fresh install (per design choice; not the macOS norm of system).
    @Published var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
            applyAppearance()
            reloadToken &+= 1   // re-render the open preview with the new body class
        }
    }

    /// When true, clicking a file in the sidebar opens it as a tab in the preview pane
    /// (preserving any already-open files). When false, each click replaces the preview.
    @Published var openInTabs: Bool {
        didSet {
            UserDefaults.standard.set(openInTabs, forKey: openInTabsKey)
            if !openInTabs {
                // Leaving tabs mode collapses to a single preview — drop all tabs except
                // the active one (which already drives the preview via `selection`).
                openTabs = openTabs.filter { $0.url == selection?.url }
            } else if let sel = selection, !sel.isDirectory,
                      !openTabs.contains(where: { $0.url == sel.url }) {
                // Entering tabs mode pins the currently-selected file as the first tab.
                openTabs.append(sel)
            }
        }
    }

    /// Currently open tabs in left-to-right order. Only meaningful when `openInTabs` is true.
    /// `selection` is the active tab; closing it picks the neighboring tab as the new active.
    @Published var openTabs: [FileNode] = []

    /// Per-file raw/rendered toggle state, keyed by URL. Lets each file (including each
    /// open tab) remember independently whether the user wants Formatted or Raw view, so
    /// switching tabs preserves each tab's mode. Cleared on folder change.
    @Published var rawStates: [URL: Bool] = [:]

    /// Full-text search results across the open folder, one entry per file with hits.
    /// Driven by `performTextSearch(_:)`; cleared when the search query is empty.
    @Published var contentSearchResults: [SearchResult] = []

    /// True while a content search is in flight (the sidebar shows a spinner row).
    @Published var isContentSearching = false

    /// Tracks the in-flight content search so a new keystroke can cancel the previous one
    /// without waiting for it to finish.
    private var contentSearchTask: Task<Void, Never>?

    /// URLs of folders currently expanded in the sidebar tree. Kept here (not in OutlineGroup)
    /// so taps can toggle expansion and so expansion survives tree reloads.
    @Published var expandedFolders: Set<URL> = []

    /// Sidebar visibility, bound to the NavigationSplitView. Lets the sidebar toolbar hide its
    /// buttons (leaving only the system toggle) when collapsed.
    @Published var columnVisibility: NavigationSplitViewVisibility = .all

    private let lastFolderKey = "Folio.lastFolderPath"
    private let lastSelectionKey = "Folio.lastSelectionPath"
    private let showHiddenKey = "Folio.showHidden"
    private let appearanceKey = "Folio.appearance"
    private let openInTabsKey = "Folio.openInTabs"
    private var watcher: FolderWatcher?
    private var knownURLs: Set<URL> = []
    /// A file the next `load` should select once its tree is ready (e.g. a file opened from
    /// Finder / `open`). Takes precedence over the persisted last-selection restore.
    private var requestedSelection: URL?
    /// Modification date of the currently-selected file, to detect when *it* (not some other
    /// file in the folder) changes on disk — so unrelated edits don't reload the open preview.
    private var selectedModDate: Date?

    nonisolated private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    init() {
        showHidden = UserDefaults.standard.bool(forKey: showHiddenKey)
        let appearanceRaw = UserDefaults.standard.string(forKey: appearanceKey) ?? Appearance.dark.rawValue
        appearance = Appearance(rawValue: appearanceRaw) ?? .dark
        openInTabs = UserDefaults.standard.bool(forKey: openInTabsKey)
        applyAppearance()
        restoreLastFolder()
    }

    /// Apply the current `appearance` setting to the AppKit chrome.
    /// `system` (`nil`) follows the user's macOS preference; `light`/`dark` force the choice.
    private func applyAppearance() {
        let nsAppearance: NSAppearance? = {
            switch appearance {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }()
        DispatchQueue.main.async { NSApp.appearance = nsAppearance }
    }

    // MARK: - Tabs

    // MARK: - Full-text search

    /// Run a full-text search for `query` across every searchable file under the open
    /// folder. Off-main thread; cancels any previous in-flight search. Cleared (and the
    /// task cancelled) when `query` is empty or shorter than 2 characters.
    func performTextSearch(_ query: String) {
        contentSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let root else {
            contentSearchResults = []
            isContentSearching = false
            return
        }
        let urls = Self.searchableFiles(under: root)
        isContentSearching = true
        contentSearchTask = Task.detached(priority: .userInitiated) {
            let results = FileSearch.search(query: trimmed, in: urls)
            if Task.isCancelled { return }
            await MainActor.run {
                // Guard against a slower task overwriting a faster newer one: only commit
                // if the user's current query still matches what we searched for.
                self.contentSearchResults = results
                self.isContentSearching = false
            }
        }
    }

    /// Walk the tree and collect every file URL whose kind is text-like (markdown, html,
    /// json, xml, csv, plain text/source). Skips directories and binary kinds.
    nonisolated private static func searchableFiles(under root: FileNode) -> [URL] {
        var out: [URL] = []
        func walk(_ node: FileNode) {
            if node.isDirectory {
                for child in node.children ?? [] { walk(child) }
            } else if FileKind(for: node.url).isSearchable {
                out.append(node.url)
            }
        }
        walk(root)
        return out
    }

    // MARK: - Tabs

    /// Close `tab`. If it was active, select the neighboring tab (right-leaning), or clear
    /// the preview if no tabs remain.
    func closeTab(_ tab: FileNode) {
        guard let idx = openTabs.firstIndex(where: { $0.url == tab.url }) else { return }
        let wasActive = (selection?.url == tab.url)
        openTabs.remove(at: idx)
        rawStates.removeValue(forKey: tab.url)   // closed tab's raw/rendered state is no longer interesting
        guard wasActive else { return }
        if openTabs.isEmpty {
            selection = nil
        } else {
            let newIdx = min(idx, openTabs.count - 1)
            selection = openTabs[newIdx]
        }
    }

    var selectedFile: FileNode? {
        guard let sel = selection, !sel.isDirectory else { return nil }
        return sel
    }

    var folderName: String? { root?.name }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder to browse"
        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    /// Open something handed to the app from outside (Finder double-click, `open` command,
    /// drag onto the Dock icon). Folders load directly; a file loads its enclosing folder and
    /// is selected in the preview, so the sidebar still works.
    func open(fileOrFolder url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            load(url)
        } else {
            requestedSelection = url
            load(url.deletingLastPathComponent())
        }
    }

    /// Load a folder's tree off the main thread, publish it, restore selection, and watch for changes.
    func load(_ url: URL) {
        isLoading = true
        UserDefaults.standard.set(url.path, forKey: lastFolderKey)
        let includeHidden = showHidden
        Task.detached(priority: .userInitiated) {
            let result = FileTreeLoader.load(url, limits: .default, includeHidden: includeHidden)
            await MainActor.run {
                self.root = result.root
                self.truncated = result.truncated
                self.knownURLs = result.root.allURLs()
                self.expandedFolders = [] // a freshly opened folder starts collapsed
                self.openTabs = []        // new folder → fresh, empty tab set
                self.rawStates = [:]      // new folder → drop any remembered raw/rendered toggles
                self.contentSearchResults = []   // stale results would refer to the old folder
                self.contentSearchTask?.cancel()
                self.isContentSearching = false
                self.selection = nil
                self.isLoading = false
                self.startWatching(url)
                // A file opened from Finder/`open` wins over the persisted last selection.
                if let requested = self.requestedSelection,
                   let node = result.root.node(withURL: requested) {
                    self.requestedSelection = nil
                    self.selection = node
                } else {
                    self.requestedSelection = nil
                    self.restoreSelection(in: result.root)
                }
            }
        }
    }

    func refresh() {
        guard let url = root?.url else { return }
        load(url)
    }

    // MARK: - Tree expansion

    func isExpanded(_ url: URL) -> Bool { expandedFolders.contains(url) }

    func toggleExpanded(_ url: URL) {
        if expandedFolders.contains(url) { expandedFolders.remove(url) }
        else { expandedFolders.insert(url) }
    }

    func expansionBinding(_ url: URL) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.expandedFolders.contains(url) ?? false },
            set: { [weak self] expand in
                guard let self else { return }
                if expand { self.expandedFolders.insert(url) } else { self.expandedFolders.remove(url) }
            }
        )
    }

    /// Re-scan the open folder after an in-app file operation (delete/rename/move) and update the
    /// tree and selection **together in one transaction**. The re-scan runs off the main thread so
    /// it never blocks the UI (no spinner/beachball), and because the selection is resolved against
    /// the fresh tree in the same update there's no blank-preview flicker.
    ///
    /// - Parameter target: the URL to select after the change (e.g. a renamed/moved file's new
    ///   location). If `nil`, the current selection is kept when it still exists, else cleared.
    func applyLocalChange(selecting target: URL?) {
        guard let folderURL = root?.url else { return }
        let includeHidden = showHidden
        let desired = target ?? selection?.url // capture on main before going async

        Task.detached(priority: .userInitiated) {
            let result = FileTreeLoader.load(folderURL, limits: .default, includeHidden: includeHidden)
            let urls = result.root.allURLs()
            let resolved = desired.flatMap { result.root.node(withURL: $0) }
            await MainActor.run {
                self.root = result.root
                self.knownURLs = urls
                self.truncated = result.truncated
                self.reloadToken &+= 1
                // Drop tabs whose files no longer exist (deleted/moved-away); keeps tab bar honest.
                self.openTabs = self.openTabs.compactMap { tab in result.root.node(withURL: tab.url) }
                self.selection = resolved // atomic with root → no flicker
            }
        }
    }

    /// Re-scan the open folder while showing a loading state (used for deliberate reloads like
    /// toggling hidden files), so the previous tree is replaced by "Loading…" rather than lingering.
    private func reloadShowingLoading() {
        guard let folderURL = root?.url else { return }
        let includeHidden = showHidden
        let desired = selection?.url
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let result = FileTreeLoader.load(folderURL, limits: .default, includeHidden: includeHidden)
            let urls = result.root.allURLs()
            let resolved = desired.flatMap { result.root.node(withURL: $0) }
            await MainActor.run {
                self.root = result.root
                self.knownURLs = urls
                self.truncated = result.truncated
                self.reloadToken &+= 1
                self.selection = resolved
                self.isLoading = false
            }
        }
    }

    // MARK: - Live reload

    private func startWatching(_ url: URL) {
        let watcher = FolderWatcher { [weak self] in
            self?.folderDidChange()
        }
        watcher.start(path: url.path)
        self.watcher = watcher
    }

    /// Called (coalesced) when anything under the open folder changes on disk.
    /// Rebuilds the tree only when the set of entries changed (so expansion is preserved), and
    /// re-renders the preview ONLY when the *selected* file itself changed — editing some other
    /// file in the folder must not disturb the open preview.
    private func folderDidChange() {
        guard let url = root?.url else { return }
        let includeHidden = showHidden
        let selectedURL = (selection?.isDirectory == false) ? selection?.url : nil
        let baseline = selectedModDate
        Task.detached(priority: .utility) {
            let result = FileTreeLoader.load(url, limits: .default, includeHidden: includeHidden)
            let urls = result.root.allURLs()
            let currentMod = selectedURL.flatMap { Self.modificationDate(of: $0) }
            await MainActor.run {
                if urls != self.knownURLs {
                    self.knownURLs = urls
                    self.root = result.root
                    self.truncated = result.truncated
                    if let sel = self.selection, !urls.contains(sel.url) {
                        self.selection = nil
                    }
                }
                // Re-render the preview only if the selected file's own contents changed.
                if selectedURL != nil, currentMod != baseline {
                    self.selectedModDate = currentMod
                    self.reloadToken &+= 1
                }
            }
        }
    }

    // MARK: - Restore

    private func restoreSelection(in root: FileNode) {
        guard let path = UserDefaults.standard.string(forKey: lastSelectionKey) else { return }
        if let found = root.node(withURL: URL(fileURLWithPath: path)) {
            selection = found
        }
    }

    private func restoreLastFolder() {
        guard let path = UserDefaults.standard.string(forKey: lastFolderKey) else { return }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            load(URL(fileURLWithPath: path))
        }
    }
}
