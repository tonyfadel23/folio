import SwiftUI
import AppKit

@main
struct FolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @StateObject private var preview = PreviewController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(preview)
                .frame(minWidth: 720, minHeight: 460)
                .onAppear { delegate.model = model }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { model.openFolderPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") { preview.findVisible = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { preview.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { preview.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { preview.zoomReset() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
            }
        }
    }
}

/// Ensures the app launches as a regular, focused GUI app when run from a .app bundle
/// built without Xcode, and quits when the window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set once the SwiftUI scene appears. When connected, any files that arrived before
    /// the model existed (a launch triggered by double-clicking a file) are flushed through.
    weak var model: AppModel? {
        didSet {
            guard let model, !pendingURLs.isEmpty else { return }
            let urls = pendingURLs
            pendingURLs = []
            // didSet fires from the scene's `.onAppear`, i.e. on the main thread.
            MainActor.assumeIsolated { urls.forEach { model.open(fileOrFolder: $0) } }
        }
    }

    /// Files handed to the app before `model` is wired up are buffered here.
    private var pendingURLs: [URL] = []

    /// Finder double-click, `open` from the terminal, or a drag onto the Dock icon.
    /// AppKit dispatches delegate callbacks on the main thread.
    func application(_ application: NSApplication, open urls: [URL]) {
        if let model {
            MainActor.assumeIsolated { urls.forEach { model.open(fileOrFolder: $0) } }
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Persist & restore the window's size and position across launches.
        DispatchQueue.main.async {
            NSApp.windows.first?.setFrameAutosaveName("FolioMainWindow")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
