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
            if controller.findVisible {
                findBar
                Divider()
            }
            PreviewPane(file: model.selectedFile,
                        reloadToken: model.reloadToken,
                        raw: raw,
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
