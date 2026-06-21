import SwiftUI

/// Two-pane layout: a fixed left sidebar (folder tree) and a right preview pane.
/// The toolbar buttons live inside the sidebar (see `SidebarView`); when the sidebar is
/// collapsed only the system sidebar toggle remains.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView(columnVisibility: $model.columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 460)
        } detail: {
            PreviewContainer()
        }
        .navigationTitle(model.selectedFile?.name ?? model.folderName ?? "Folio")
    }
}
