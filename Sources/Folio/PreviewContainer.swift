import SwiftUI
import FolioCore

/// The detail side: a format toggle (for Markdown/HTML), an optional find bar, and the preview.
struct PreviewContainer: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var controller: PreviewController
    @FocusState private var findFocused: Bool
    /// false = rendered (Formatted/Website), true = raw source (Raw/Code).
    @State private var raw = false

    /// Rendered/raw labels for the current file, or nil if its kind has no toggle.
    private var toggle: (rendered: String, raw: String)? {
        guard let file = model.selectedFile else { return nil }
        return FileKind(for: file.url).previewToggle
    }

    /// Whether the selected file can be copied as rich text (renders to formatted content).
    private var canCopyRich: Bool {
        guard let file = model.selectedFile else { return false }
        let kind = FileKind(for: file.url)
        return kind == .markdown || kind == .html
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.openInTabs && !model.openTabs.isEmpty {
                tabBar
                Divider()
            }
            if controller.findVisible {
                findBar
                Divider()
            }
            PreviewPane(file: model.selectedFile,
                        reloadToken: model.reloadToken,
                        raw: raw,
                        theme: model.appearance,
                        controller: controller)
        }
        .toolbar {
            // Right-aligned on the title-bar line; only shown when relevant to the file.
            ToolbarItemGroup(placement: .primaryAction) {
                if let toggle {
                    Picker("View", selection: $raw) {
                        Text(toggle.rendered).tag(false)
                        Text(toggle.raw).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }
                if canCopyRich {
                    Button {
                        if let url = model.selectedFile?.url { copyAsRichText(url) }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy as rich text — paste into Google Docs, Word, etc. with formatting")
                }
            }
        }
        .onChange(of: model.selectedFile) { _ in raw = false } // each file starts in rendered mode
        .onChange(of: controller.findVisible) { visible in
            if visible { findFocused = true }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(model.openTabs) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(.bar)
    }

    private func tabItem(_ tab: FileNode) -> some View {
        let isActive = model.selection?.url == tab.url
        return HStack(spacing: 6) {
            Image(systemName: fileIcon(tab))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(tab.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                model.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.001))
        )
        .frame(maxWidth: 200)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = tab }
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find in page", text: $controller.findText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .focused($findFocused)
                .onSubmit { controller.find(forward: true) }
                .onChange(of: controller.findText) { _ in controller.find(forward: true) }

            Button { controller.find(forward: false) } label: { Image(systemName: "chevron.up") }
                .help("Previous match")
            Button { controller.find(forward: true) } label: { Image(systemName: "chevron.down") }
                .help("Next match")
            Spacer()
            Button("Done") { controller.endFind() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}
