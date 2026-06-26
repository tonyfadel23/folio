import SwiftUI
import AppKit
import FolioCore

/// The left pane: a search box, an "Open Folder" control, and the file/subfolder tree.
/// While searching, the tree is replaced by a flat list of matching files (with their paths)
/// so nested matches are visible without expanding folders.
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var updates = UpdateChecker()
    @State private var query = ""
    @State private var pendingDelete: FileNode?
    @State private var renameTarget: FileNode?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var dropTarget: URL?
    @State private var showSettings = false

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if model.isLoading {
                loadingView
            } else if let root = model.root {
                if trimmedQuery.isEmpty {
                    treeList(root)
                } else {
                    searchResults(root)
                }
            } else {
                emptyState
            }
        }
        .onChange(of: query) { newValue in
            // Kick off full-text search alongside the name-filter. AppModel debounces by
            // cancelling the in-flight task when a fresh keystroke arrives.
            model.performTextSearch(newValue)
        }
        .safeAreaInset(edge: .bottom) {
            if model.truncated {
                Label("Large folder — some items not shown", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(8)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Filter files")
        .toolbar {
            // Buttons live inside the sidebar; hidden when collapsed so only the
            // system sidebar toggle remains (no overflow chevron).
            ToolbarItemGroup {
                if model.columnVisibility != .detailOnly {
                    Button { showSettings.toggle() } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .help("Settings")
                    .popover(isPresented: $showSettings, arrowEdge: .bottom) { settingsPopover }

                    Button { model.openFolderPanel() } label: {
                        Label("Open Folder", systemImage: "folder")
                    }
                    .help("Open a folder to browse")
                }
            }
        }
        .confirmationDialog(
            "Move “\(pendingDelete?.name ?? "")” to Trash?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let node = pendingDelete { performDelete(node) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .alert("Rename",
               isPresented: Binding(get: { renameTarget != nil },
                                    set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") { performRename(); renameTarget = nil }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        } message: {
            Text("Enter a new name for “\(renameTarget?.name ?? "")”.")
        }
        .alert("Error",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - File operations

    private func performDelete(_ node: FileNode) {
        do {
            try FileOperations.moveToTrash(node.url)
            // Tree + selection update atomically; the deleted file's selection auto-clears.
            model.applyLocalChange(selecting: nil)
        } catch {
            errorMessage = "Couldn’t move “\(node.name)” to Trash.\n\(error.localizedDescription)"
        }
    }

    private func performRename() {
        guard let node = renameTarget else { return }
        do {
            let newURL = try FileOperations.rename(node.url, to: renameText)
            let wasSelected = model.selection?.url == node.url
            model.applyLocalChange(selecting: wasSelected ? newURL : nil)
        } catch {
            errorMessage = "Couldn’t rename “\(node.name)”.\n\(error.localizedDescription)"
        }
    }

    /// Move dropped items into `folder`. Returns true if at least one item moved.
    @discardableResult
    private func handleDrop(_ urls: [URL], into folder: FileNode) -> Bool {
        guard folder.isDirectory else { return false }
        var moved = false
        var reselect: URL?
        for url in urls {
            do {
                let wasSelected = model.selection?.url == url
                let newURL = try FileOperations.move(url, into: folder.url)
                if wasSelected { reselect = newURL }
                moved = true
            } catch FileOperations.OperationError.sameLocation {
                continue // dropped into its own folder — ignore silently
            } catch FileOperations.OperationError.invalidDestination {
                errorMessage = "Can’t move a folder into itself."
            } catch {
                errorMessage = "Couldn’t move “\(url.lastPathComponent)”.\n\(error.localizedDescription)"
            }
        }
        if moved { model.applyLocalChange(selecting: reselect) }
        return moved
    }

    // MARK: - Tree (no active search)

    private func treeList(_ root: FileNode) -> some View {
        List(selection: $model.selection) {
            ForEach(root.children ?? []) { node in
                TreeNodeRow(node: node,
                            pendingDelete: $pendingDelete,
                            renameTarget: $renameTarget,
                            renameText: $renameText,
                            dropTarget: $dropTarget,
                            onDrop: handleDrop)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Flat search results

    private func searchResults(_ root: FileNode) -> some View {
        let nameMatches = root.matchingFiles(query: trimmedQuery)
        let contentMatches = model.contentSearchResults

        return Group {
            if nameMatches.isEmpty && contentMatches.isEmpty && !model.isContentSearching {
                ContentUnavailableMessage(text: "No files or content match “\(trimmedQuery)”")
            } else {
                List(selection: $model.selection) {
                    if !nameMatches.isEmpty {
                        Section("Files (\(nameMatches.count))") {
                            ForEach(nameMatches) { node in
                                HStack(spacing: 8) {
                                    Image(systemName: fileIcon(node))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(node.name).lineLimit(1)
                                        let sub = relativeFolder(of: node, root: root)
                                        if !sub.isEmpty {
                                            Text(sub)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .opacity(isEffectivelyHidden(node, root: root) ? 0.45 : 1)
                                .tag(node)
                                .contextMenu { fileActions(for: node) }
                                .draggable(node.url)
                            }
                        }
                    }

                    if model.isContentSearching {
                        Section("In files") {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Searching contents…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else if !contentMatches.isEmpty {
                        let totalHits = contentMatches.reduce(0) { $0 + $1.hits.count }
                        Section("In files (\(totalHits) match\(totalHits == 1 ? "" : "es") in \(contentMatches.count) file\(contentMatches.count == 1 ? "" : "s"))") {
                            ForEach(contentMatches) { result in
                                contentMatchRow(result, root: root)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    /// One file's worth of content-search rows: a filename header + one row per matching line.
    /// Clicking a hit selects the file in the preview pane (so the user can ⌘F to jump to
    /// the exact match if needed).
    @ViewBuilder
    private func contentMatchRow(_ result: SearchResult, root: FileNode) -> some View {
        let node = model.root?.node(withURL: result.url)
        let relPath = node.map { relativeFolder(of: $0, root: root) } ?? ""

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: node.map(fileIcon) ?? "doc")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                Text(result.url.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if !relPath.isEmpty {
                    Text(relPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            ForEach(result.hits, id: \.line) { hit in
                snippetView(for: hit, query: trimmedQuery)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let n = node { model.selection = n }
                    }
            }
        }
        .padding(.vertical, 2)
    }

    /// One matching line, with the matched substring bolded.
    @ViewBuilder
    private func snippetView(for hit: SearchHit, query: String) -> some View {
        let displayLine = hit.text.trimmingCharacters(in: .whitespaces)
        HStack(alignment: .top, spacing: 6) {
            Text("\(hit.line)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 24, alignment: .trailing)
            Text(attributedSnippet(displayLine, query: query))
                .font(.system(size: 11))
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 22)
    }

    /// Build an AttributedString with `query` highlighted (bold + primary color) inside
    /// `line`. Returns the line unmodified if the match can't be located (shouldn't happen
    /// since `FileSearch` only returns hits that contain the needle).
    private func attributedSnippet(_ line: String, query: String) -> AttributedString {
        var attr = AttributedString(line)
        if let range = line.range(of: query, options: .caseInsensitive),
           let attrRange = Range(range, in: attr) {
            attr[attrRange].font = .system(size: 11, weight: .semibold)
            attr[attrRange].foregroundColor = .primary
        }
        return attr
    }

    /// True if the node is hidden or lives anywhere inside a hidden (dot-prefixed) folder.
    private func isEffectivelyHidden(_ node: FileNode, root: FileNode) -> Bool {
        if node.isHidden { return true }
        let rootPath = root.url.path
        let full = node.url.path
        guard full.hasPrefix(rootPath) else { return false }
        return full.dropFirst(rootPath.count).split(separator: "/").contains { $0.hasPrefix(".") }
    }

    /// Folder of `node` relative to the opened root (empty string if directly in root).
    private func relativeFolder(of node: FileNode, root: FileNode) -> String {
        let rootPath = root.url.path
        var path = node.url.deletingLastPathComponent().path
        if path.hasPrefix(rootPath) { path = String(path.dropFirst(rootPath.count)) }
        return path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Empty state

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No folder open").font(.headline)
            Button("Open Folder…") { model.openFolderPanel() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Settings popover: app version + preferences.
    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Folio").font(.headline)
                Spacer()
                Text("v\(AppInfo.version)").font(.subheadline).foregroundStyle(.secondary)
            }
            updateRow
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance").font(.subheadline)
                Picker("Appearance", selection: $model.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Open files").font(.subheadline)
                Picker("Open files", selection: $model.openInTabs) {
                    Text("One at a time").tag(false)
                    Text("In tabs").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Divider()
            Toggle("Show hidden files & folders", isOn: $model.showHidden)
                .toggleStyle(.switch)
        }
        .padding(16)
        .frame(width: 320)
    }

    /// One-line update status: button to check on demand, spinner while in flight, then a
    /// result + action. Never auto-checks; only hits GitHub when the user clicks.
    @ViewBuilder
    private var updateRow: some View {
        HStack(spacing: 8) {
            switch updates.state {
            case .idle:
                Button("Check for Updates") {
                    Task { await updates.check(current: AppInfo.version) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()

            case .checking:
                ProgressView().controlSize(.small)
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
                Spacer()

            case .result(.upToDate):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("You're on the latest version.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Check Again") {
                    Task { await updates.check(current: AppInfo.version) }
                }
                .buttonStyle(.borderless).controlSize(.small)

            case .result(.updateAvailable(let latest, let url)):
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
                Text("v\(latest) is available.")
                    .font(.caption)
                Spacer()
                Button("View") { NSWorkspace.shared.open(url) }
                    .buttonStyle(.borderedProminent).controlSize(.small)

            case .result(.ahead(let latest)):
                Image(systemName: "hammer.fill").foregroundStyle(.secondary)
                Text("Dev build (latest released: v\(latest)).")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button("Retry") {
                    Task { await updates.check(current: AppInfo.version) }
                }
                .buttonStyle(.borderless).controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func fileActions(for node: FileNode) -> some View {
        FileActionsMenu(node: node,
                        renameTarget: $renameTarget,
                        renameText: $renameText,
                        pendingDelete: $pendingDelete)
    }
}

/// Render a Markdown/HTML file and place rich text on the clipboard (RTF + HTML + plain),
/// so pasting into Google Docs, Word, Pages, etc. preserves formatting.
@discardableResult
func copyAsRichText(_ url: URL) -> Bool {
    let kind = FileKind(for: url)
    guard kind == .markdown || kind == .html,
          let text = try? String(contentsOf: url, encoding: .utf8) else { NSSound.beep(); return false }

    let body = kind == .markdown ? MarkdownRenderer().html(from: text) : text
    let fullHTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>\(body)</body></html>"

    guard let data = fullHTML.data(using: .utf8),
          let attributed = try? NSAttributedString(
              data: data,
              options: [.documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue],
              documentAttributes: nil)
    else { NSSound.beep(); return false }

    let pb = NSPasteboard.general
    pb.clearContents()
    pb.declareTypes([.rtf, .html, .string], owner: nil)
    if let rtf = try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
        pb.setData(rtf, forType: .rtf)
    }
    pb.setString(fullHTML, forType: .html)   // browsers (Google Docs) read text/html
    pb.setString(text, forType: .string)     // plain-text fallback
    return true
}

/// SF Symbol for a node, by kind. File-scope so both the tree and search results share it.
func fileIcon(_ node: FileNode) -> String {
    if node.isDirectory { return "folder" }
    switch FileKind(for: node.url) {
    case .markdown: return "doc.text"
    case .html: return "globe"
    case .image, .svg: return "photo"
    case .pdf: return "doc.richtext"
    case .csv: return "tablecells"
    case .json, .xml: return "curlybraces"
    case .text: return "doc.plaintext"
    case .other: return "doc"
    }
}

/// The right-click menu shared by tree rows and search results.
struct FileActionsMenu: View {
    let node: FileNode
    @Binding var renameTarget: FileNode?
    @Binding var renameText: String
    @Binding var pendingDelete: FileNode?

    var body: some View {
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
        Button("Open in Default App") { NSWorkspace.shared.open(node.url) }
        Button("Open Enclosing Folder") { NSWorkspace.shared.open(node.url.deletingLastPathComponent()) }
        Divider()
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.url.path, forType: .string)
        }
        if FileKind(for: node.url) == .markdown || FileKind(for: node.url) == .html {
            Button("Copy as Rich Text") { copyAsRichText(node.url) }
        }
        Divider()
        Button("Rename…") { renameText = node.name; renameTarget = node }
        Button("Move to Trash", role: .destructive) { pendingDelete = node }
    }
}

/// A recursive tree row. Folders are `DisclosureGroup`s whose expansion is driven by the model,
/// so tapping anywhere on a folder row toggles it open/closed. Files are selectable leaf rows.
struct TreeNodeRow: View {
    let node: FileNode
    /// True when an ancestor folder is hidden, so this row dims even if its own name isn't dotted.
    var parentHidden: Bool = false
    @EnvironmentObject private var model: AppModel
    @Binding var pendingDelete: FileNode?
    @Binding var renameTarget: FileNode?
    @Binding var renameText: String
    @Binding var dropTarget: URL?
    let onDrop: ([URL], FileNode) -> Bool

    private var effectiveHidden: Bool { parentHidden || node.isHidden }

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: model.expansionBinding(node.url)) {
                ForEach(node.children ?? []) { child in
                    TreeNodeRow(node: child,
                                parentHidden: effectiveHidden,
                                pendingDelete: $pendingDelete,
                                renameTarget: $renameTarget,
                                renameText: $renameText,
                                dropTarget: $dropTarget,
                                onDrop: onDrop)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .lineLimit(1)
                    .opacity(effectiveHidden ? 0.45 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { model.toggleExpanded(node.url) } }
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(dropTarget == node.url ? Color.accentColor.opacity(0.25) : Color.clear)
                    )
                    .draggable(node.url)
                    .dropDestination(for: URL.self) { urls, _ in
                        onDrop(urls, node)
                    } isTargeted: { targeted in
                        dropTarget = targeted ? node.url : (dropTarget == node.url ? nil : dropTarget)
                    }
                    .contextMenu {
                        FileActionsMenu(node: node, renameTarget: $renameTarget,
                                        renameText: $renameText, pendingDelete: $pendingDelete)
                    }
            }
        } else {
            Label(node.name, systemImage: fileIcon(node))
                .lineLimit(1)
                .opacity(effectiveHidden ? 0.45 : 1)
                .tag(node)
                .draggable(node.url)
                .contextMenu {
                    FileActionsMenu(node: node, renameTarget: $renameTarget,
                                    renameText: $renameText, pendingDelete: $pendingDelete)
                }
        }
    }
}

/// Simple centered message used when a search has no results.
private struct ContentUnavailableMessage: View {
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
