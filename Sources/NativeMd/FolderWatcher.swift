import Foundation
import CoreServices

/// Watches a directory tree with FSEvents and fires `onChange` (coalesced) on any change.
/// macOS-native, no dependencies. The callback is delivered on the main queue.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit { stop() }

    func start(path: String) {
        stop()

        // Unretained: the owner (AppModel) keeps this watcher alive, and `deinit`/`stop`
        // invalidate the stream before dealloc, so the callback can never outlive `self`.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientInfo, _, _, _, _ in
            guard let clientInfo else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            watcher.onChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.4, // latency: coalesce rapid bursts (e.g. editor saves)
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
