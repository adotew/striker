import Foundation
import CoreServices

final class FileWatcher {

    var onEvents: (([URL]) -> Void)?

    private var stream: FSEventStreamRef?
    private let callbackQueue = DispatchQueue(label: "striker.filewatcher.events")
    private var pendingPaths = Set<String>()
    private var debounceItem: DispatchWorkItem?
    private var ignoredPaths: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 0.1
    private let ignoreInterval: TimeInterval = 0.6

    deinit {
        stop()
    }

    func startWatching(rootURL: URL) {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [rootURL.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, clientCallBackInfo, numEvents, eventPaths, _, _ in
                guard let clientCallBackInfo, numEvents > 0 else { return }
                let watcher = Unmanaged<FileWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
                guard !paths.isEmpty else { return }
                watcher.handleIncoming(paths: paths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, callbackQueue)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceItem?.cancel()
        debounceItem = nil
        pendingPaths.removeAll()
        ignoredPaths.removeAll()

        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    func ignore(url: URL) {
        let path = url.standardizedFileURL.path
        ignoredPaths[path] = Date().addingTimeInterval(ignoreInterval)
    }

    private func handleIncoming(paths: [String]) {
        let now = Date()
        ignoredPaths = ignoredPaths.filter { $0.value > now }

        for path in paths {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if ignoredPaths[normalized] != nil {
                continue
            }
            pendingPaths.insert(normalized)
        }

        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.pendingPaths.isEmpty else { return }
            let urls = self.pendingPaths
                .map { URL(fileURLWithPath: $0) }
                .sorted { $0.path < $1.path }
            self.pendingPaths.removeAll()
            DispatchQueue.main.async { [weak self] in
                self?.onEvents?(urls)
            }
        }
        debounceItem = item
        callbackQueue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }
}
