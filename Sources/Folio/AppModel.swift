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

    /// URLs of folders currently expanded in the sidebar tree. Kept here (not in OutlineGroup)
    /// so taps can toggle expansion and so expansion survives tree reloads.
    @Published var expandedFolders: Set<URL> = []

    /// Sidebar visibility, bound to the NavigationSplitView. Lets the sidebar toolbar hide its
    /// buttons (leaving only the system toggle) when collapsed.
    @Published var columnVisibility: NavigationSplitViewVisibility = .all

    private let lastFolderKey = "Folio.lastFolderPath"
    private let lastSelectionKey = "Folio.lastSelectionPath"
    private let showHiddenKey = "Folio.showHidden"
    private var watcher: FolderWatcher?
    private var knownURLs: Set<URL> = []
    /// Modification date of the currently-selected file, to detect when *it* (not some other
    /// file in the folder) changes on disk — so unrelated edits don't reload the open preview.
    private var selectedModDate: Date?

    nonisolated private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    init() {
        showHidden = UserDefaults.standard.bool(forKey: showHiddenKey)
        restoreLastFolder()
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
                self.selection = nil
                self.isLoading = false
                self.startWatching(url)
                self.restoreSelection(in: result.root)
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
