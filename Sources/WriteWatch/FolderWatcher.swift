import Foundation

/// Polls a directory for video files whose size changes, firing `onUpdate`.
/// Polling (not FSEvents) is intentional — it works on SMB/NFS shares and for
/// files that are actively growing.
///
/// Honors both a configurable poll interval and a `recursive` flag:
///   • recursive = true  → walks the whole tree
///   • recursive = false → only the top-level directory (no sub-folders)
final class FolderWatcher {

    private let rootURL:    URL
    private let onUpdate:   (String) -> Void
    private let recursive:  Bool
    private let interval:   TimeInterval
    private var timer:      DispatchSourceTimer?
    private let queue       = DispatchQueue(label: "com.writewatch.poller", qos: .utility)

    private var knownSizes: [String: Int64] = [:]

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "mxf", "r3d", "braw",
        "m4v", "wmv", "flv", "webm", "ts",  "m2ts", "mts",
        "mpg", "mpeg", "3gp", "hevc", "h264", "prores"
    ]

    init(path: String,
         recursive: Bool,
         interval: TimeInterval,
         onUpdate: @escaping (String) -> Void) {
        self.rootURL   = URL(fileURLWithPath: path)
        self.recursive = recursive
        self.interval  = max(0.25, interval)   // floor to avoid runaway polling
        self.onUpdate  = onUpdate
        start()
    }

    deinit { stop() }

    private func start() {
        let t = DispatchSource.makeTimerSource(flags: [], queue: queue)
        t.schedule(deadline: .now() + 0.1,
                   repeating: interval,
                   leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        let urls: [URL]
        if recursive {
            // Full tree walk
            guard let en = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            var collected: [URL] = []
            while let u = en.nextObject() as? URL { collected.append(u) }
            urls = collected
        } else {
            // Top level only — no sub-folder descent
            guard let listing = try? FileManager.default.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            urls = listing
        }

        for url in urls {
            guard Self.videoExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let path = url.path
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                           .map(Int64.init) ?? 0
            let prev = knownSizes[path]
            if prev == nil || prev != size {
                knownSizes[path] = size
                let cb = onUpdate
                Task { @MainActor in cb(path) }
            }
        }
    }
}
