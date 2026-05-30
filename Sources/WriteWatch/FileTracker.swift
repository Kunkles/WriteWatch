import Foundation
import AppKit

private let videoExtensions: Set<String> = [
    "mp4", "mov", "avi", "mkv", "mxf", "r3d", "braw",
    "m4v", "wmv", "flv", "webm", "ts",  "m2ts", "mts",
    "mpg", "mpeg", "3gp", "hevc", "h264", "prores"
]

// After this many seconds with no size change, a file is considered done.
private let discoveryGrace:  TimeInterval = 12
// How often (seconds) we run the active-file lsof scan to catch mid-join files.
private let lsofScanInterval: TimeInterval = 8.0   // gentle; only used when passiveMode is off

@MainActor
final class FileTracker: ObservableObject {

    @Published var entries:        [String: FileEntry] = [:]
    @Published var completedPaths: [String] = []
    @Published var totalWritten:   Int64 = 0

    /// True while scanExisting is enumerating + populating entries. The watcher
    /// runs in parallel with scanning, so update() must ignore events for files
    /// it hasn't seen yet during a scan — otherwise pre-existing files would be
    /// created as .writing entries before the scan can mark them as .done.
    private(set) var isScanning: Bool = false

    var soundEnabled = false

    private let probeSem      = AsyncSemaphore(limit: 3)
    private let probeService  = AVProbeService()
    private var lastLsofScan: Date = .distantPast

    // Root path this tracker is watching — set by WatchedFolder after init.
    var watchPath: String = ""

    // MARK: - Computed views

    var activeEntries: [FileEntry] {
        entries.values
            .filter  { $0.status == .writing }
            .sorted  { $0.started < $1.started }
    }

    var recentCompleted: [FileEntry] {
        completedPaths.reversed().compactMap { entries[$0] }
    }

    var hasActiveTransfers: Bool { !activeEntries.isEmpty }

    // MARK: - Update (called from FolderWatcher on every size change)

    func update(path: String) {
        let url = URL(fileURLWithPath: path)
        guard videoExtensions.contains(url.pathExtension.lowercased()) else { return }

        let now = Date()
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: path),
            let size  = attrs[.size] as? Int64
        else { return }

        // During a scan, ignore events for files we haven't entered yet.
        // The scan will register them as .done shortly; without this guard they
        // would be created as brand-new .writing entries and incorrectly appear
        // in Active Transfers.
        if isScanning, entries[path] == nil { return }

        if var entry = entries[path] {
            if entry.status == .done && entry.isPreExisting && size != entry.size {
                // ── Resurrection ──────────────────────────────────────────────
                // scanExisting marked this file .done, but its size is now
                // changing — it was being written when the folder was added.
                // Convert to a mid-join active entry and pull back from completed.
                let oldSize        = entry.size
                entry.status       = .writing
                entry.isMidJoin    = true
                entry.discoveredAt = now
                entry.lastCheck    = now
                entry.lastSize     = oldSize
                entry.size         = size
                entry.rate         = 0
                entry.events       = 1
                entry.validation   = .none
                entry.finished     = nil
                entry.duration     = nil
                entry.baselineSize = oldSize
                entries[path]      = entry
                completedPaths.removeAll { $0 == path }
                totalWritten       = max(0, totalWritten - oldSize)
            } else if entry.status == .writing {
                let dt = now.timeIntervalSince(entry.lastCheck)
                if dt > 0 {
                    let delta      = Double(size - entry.lastSize)
                    entry.rate     = max(0, delta / dt)
                    entry.peakRate = max(entry.peakRate, entry.rate)
                }
                entry.lastSize   = entry.size
                entry.size       = size
                entry.lastCheck  = now
                entry.events    += 1
                entry.validation = .none
                entries[path]    = entry
            }
            // .done && !isPreExisting → truly finished, ignore
        } else {
            // Brand-new path — never seen before.
            entries[path] = FileEntry(
                path: path, name: url.lastPathComponent,
                size: size, lastSize: size, lastCheck: now,
                rate: 0, peakRate: 0, status: .writing,
                started: now, finished: nil, duration: nil,
                events: 1, validation: .none,
                isPreExisting: false, isMidJoin: false,
                discoveredAt: now, baselineSize: size
            )
            playSound("started")   // fires once per file, on first detection
        }
    }

    // MARK: - lsof scan: find video files open for writing that we haven't seen yet

    func scanForOpenFiles() async {
        // Passive mode: never run lsof — avoids any filesystem contention that
        // could disrupt a camera actively writing to the watched volume.
        // Mid-join detection still works via size-change resurrection in update().
        if AppSettings.shared.passiveMode { return }

        let now = Date()
        guard now.timeIntervalSince(lastLsofScan) >= lsofScanInterval,
              !watchPath.isEmpty
        else { return }
        lastLsofScan = now

        // Run lsof in background to find files open for writing under our watch path
        let openFiles = await Task.detached(priority: .utility) { [watchPath = self.watchPath] in
            lsofOpenFilesForWriting(under: watchPath)
        }.value

        for (filePath, currentSize) in openFiles {
            // Skip if we already know about this file
            guard entries[filePath] == nil else { continue }

            let url = URL(fileURLWithPath: filePath)
            guard videoExtensions.contains(url.pathExtension.lowercased()) else { continue }

            // File is open for writing right now — add it as mid-join
            entries[filePath] = FileEntry(
                path: filePath, name: url.lastPathComponent,
                size: currentSize, lastSize: currentSize, lastCheck: now,
                rate: 0, peakRate: 0, status: .writing,
                started: now, finished: nil, duration: nil,
                events: 0, validation: .none,
                isPreExisting: false, isMidJoin: true,
                discoveredAt: now, baselineSize: currentSize
            )
        }
    }


    // lsof helper moved to free function below


    // MARK: - Mark stale

    func markStale(after staleSecs: TimeInterval = 4) {
        let now   = Date()
        let paths = entries.keys.sorted()

        for path in paths {
            guard var entry = entries[path],
                  entry.status == .writing
            else { continue }

            let timeSinceChange    = now.timeIntervalSince(entry.lastCheck)
            let timeSinceDiscovery = now.timeIntervalSince(entry.discoveredAt)

            guard timeSinceChange    > staleSecs,
                  timeSinceDiscovery > discoveryGrace
            else { continue }

            entry.status   = .done
            entry.rate     = 0
            entry.finished = now
            // duration left nil — the validation probe fills it with the
            // file's actual media playback length.
            entry.duration = nil

            // For mid-join files the "size" we tracked is only what we saw
            // after joining.  totalWritten only counts what we observed.
            entries[path]  = entry
            totalWritten  += entry.size
            completedPaths.append(path)

            playSound("complete")

            // After a mid-join file completes, probe it for the real final size
            // and update our record — then no duplicate, correct total.
            if entry.isMidJoin {
                updateFinalSize(path: path)
            }

            validateAsync(path: path, silent: false)
        }
    }

    // MARK: - Final size update for mid-join files

    private func updateFinalSize(path: String) {
        Task {
            // Brief delay to let the writing process close the file
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let finalSize = attrs[.size] as? Int64
            else { return }

            await MainActor.run {
                guard var entry = self.entries[path], entry.status == .done else { return }
                let oldSize = entry.size
                entry.size  = finalSize
                self.entries[path] = entry
                // Adjust the session total to reflect the true final size
                self.totalWritten += (finalSize - oldSize)
            }
        }
    }

    // MARK: - Scan existing files on startup

    func scanExisting(at watchPath: String, recursive: Bool = true) async -> Int {
        isScanning = true
        defer { isScanning = false }

        let found: [(Date, URL, Int64)] = await Task.detached(priority: .utility) {
            var results: [(Date, URL, Int64)] = []
            let fm = FileManager.default
            let root = URL(fileURLWithPath: watchPath)
            let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

            let urls: [URL]
            if recursive {
                guard let en = fm.enumerator(at: root,
                                             includingPropertiesForKeys: keys,
                                             options: [.skipsHiddenFiles]) else { return results }
                var c: [URL] = []
                while let u = en.nextObject() as? URL { c.append(u) }
                urls = c
            } else {
                urls = (try? fm.contentsOfDirectory(at: root,
                                                    includingPropertiesForKeys: keys,
                                                    options: [.skipsHiddenFiles])) ?? []
            }

            for url in urls {
                guard videoExtensions.contains(url.pathExtension.lowercased()) else { continue }
                let r     = try? url.resourceValues(forKeys: Set(keys))
                let mtime = r?.contentModificationDate ?? Date()
                let size  = Int64(r?.fileSize ?? 0)
                results.append((mtime, url, size))
            }
            return results.sorted { $0.0 < $1.0 }
        }.value

        let now = Date()
        for (mtime, url, size) in found {
            let path = url.path
            entries[path] = FileEntry(
                path: path, name: url.lastPathComponent,
                size: size, lastSize: size, lastCheck: mtime,
                rate: 0, peakRate: 0, status: .done,
                started: mtime, finished: mtime, duration: nil,
                events: 0, validation: .checking,
                isPreExisting: true, isMidJoin: false,
                discoveredAt: now, baselineSize: 0
            )
            completedPaths.append(path)
            totalWritten += size
            validateAsync(path: path, silent: true)
        }

        return found.count
    }

    // MARK: - Reset

    func reset() {
        entries        = [:]
        completedPaths = []
        totalWritten   = 0
        lastLsofScan   = .distantPast
    }

    /// Removes only the completed-file history, keeping any in-progress writes.
    /// Used by the Clear History menu action.
    func clearHistory() {
        for path in completedPaths {
            entries.removeValue(forKey: path)
        }
        completedPaths = []
        totalWritten   = 0
    }

    // MARK: - Validation

    private func validateAsync(path: String, silent: Bool) {
        entries[path]?.validation = .checking

        Task {
            await probeSem.wait()

            let isOpen = AppSettings.shared.passiveMode
                ? false                              // skip lsof in passive mode
                : await checkFileOpen(path)
            if isOpen {
                await MainActor.run { self.entries[path]?.validation = .stillOpen }
                if !silent { playSound("open") }
                await probeSem.signal()
                return
            }

            let outcome = await probeService.probe(path: path)
            let state: ValidationState = {
                switch outcome.state {
                case .valid:        return .valid(outcome.detail)
                case .corrupt:      return .corrupt(outcome.detail)
                case .notAvailable: return .noProbe
                }
            }()

            await MainActor.run {
                self.entries[path]?.validation = state
                if let secs = outcome.durationSeconds, secs > 0 {
                    self.entries[path]?.duration = secs
                }
                self.entries[path]?.isVFR = outcome.isVFR
                self.entries[path]?.frameRate = outcome.frameRate
            }

            if !silent {
                switch state {
                case .valid:   playSound("valid")
                case .corrupt: playSound("corrupt")
                default: break
                }
            }
            await probeSem.signal()
        }
    }

    private func checkFileOpen(_ path: String) async -> Bool {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                proc.arguments = [path]
                let out = Pipe(); let err = Pipe()
                proc.standardOutput = out; proc.standardError = err
                try? proc.run(); proc.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                cont.resume(returning: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // Cache for bundled custom sounds — avoids re-decoding on every event.
    private static var customSoundCache: [String: NSSound] = [:]

    private func playSound(_ event: String) {
        guard AppSettings.shared.soundEnabled || soundEnabled else { return }

        // Bundled custom sounds (file in Resources/) take priority.
        let customSounds: [String: String] = [
            "started": "rec_start"          // 600 Hz lead + 10ms gap + 1000 Hz trail
        ]
        if let resourceName = customSounds[event] {
            if let cached = Self.customSoundCache[resourceName] {
                cached.play()
                return
            }
            if let url = Bundle.main.url(forResource: resourceName, withExtension: "aiff"),
               let sound = NSSound(contentsOf: url, byReference: true) {
                Self.customSoundCache[resourceName] = sound
                sound.play()
                return
            }
            // Fall through to system sound if the bundle lookup somehow fails
        }

        // Built-in macOS system sounds
        let systemMap = ["complete": "Ping", "valid": "Hero",
                         "corrupt": "Basso", "open": "Funk"]
        guard let name = systemMap[event] else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}

// MARK: - lsof free function
// Lives outside FileTracker so Task.detached (which is nonisolated) can call
// it without hitting the @MainActor restriction.

func lsofOpenFilesForWriting(under root: String) -> [(String, Int64)] {
    // Strategy: enumerate video files in the directory ourselves (fast, no
    // subprocess), then run a single lsof call with those specific paths.
    // This is O(files_in_dir) rather than O(all_open_fds_on_system) like +D.

    let videoExtensions: Set<String> = [
        "mp4","mov","avi","mkv","mxf","r3d","braw","m4v","wmv","flv",
        "webm","ts","m2ts","mts","mpg","mpeg","3gp","hevc","h264","prores"
    ]

    let fm  = FileManager.default
    let url = URL(fileURLWithPath: root)

    guard let enumerator = fm.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    var candidates: [String] = []
    while let fileURL = enumerator.nextObject() as? URL {
        guard videoExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
        candidates.append(fileURL.path)
    }
    guard !candidates.isEmpty else { return [] }

    // Run lsof with just the candidate file paths — no +D, no full tree scan
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    proc.arguments = ["-F", "an"] + candidates   // a=access, n=name; no pid needed
    let outPipe = Pipe()
    proc.standardOutput = outPipe
    proc.standardError  = Pipe()
    do { try proc.run() } catch { return [] }
    proc.waitUntilExit()

    let raw  = outPipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: raw, encoding: .utf8) ?? ""

    var results: [(String, Int64)] = []
    var currentAccess = ""
    var currentName   = ""

    for line in text.components(separatedBy: "\n") {
        guard let first = line.first else { continue }
        let value = String(line.dropFirst())
        switch first {
        case "a": currentAccess = value
        case "n":
            currentName = value
            if (currentAccess == "w" || currentAccess == "u"),
               !currentName.isEmpty {
                let size = (try? FileManager.default
                    .attributesOfItem(atPath: currentName)[.size] as? Int64) ?? 0
                results.append((currentName, size))
            }
            currentAccess = ""
            currentName   = ""
        default: break
        }
    }

    var seen = Set<String>()
    return results.filter { seen.insert($0.0).inserted }
}
