import Foundation
import AppKit

// MARK: - WatchedFolder

@MainActor
final class WatchedFolder: ObservableObject, Identifiable {

    let id   = UUID()
    let path: String

    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }

    // MARK: - Volume / disk space

    /// Bytes of free space available for writing on the volume containing this folder.
    var freeSpace: Int64? {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return important
        }
        if let avail = values.volumeAvailableCapacity {
            return Int64(avail)
        }
        return nil
    }

    /// Total size of the volume containing this folder, in bytes.
    var totalSpace: Int64? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]),
              let total = values.volumeTotalCapacity
        else { return nil }
        return Int64(total)
    }

    /// Fraction of the volume used, 0.0-1.0. Nil if capacity unavailable.
    var usedFraction: Double? {
        guard let total = totalSpace, total > 0, let free = freeSpace else { return nil }
        return Double(total - free) / Double(total)
    }

    // ── State ──────────────────────────────────────────────────────────────
    @Published var isWatching   = false
    @Published var existingCount = 0

    // ── Settings (per-folder) ──────────────────────────────────────────────
    var label:                 String   = ""
    var recursive:             Bool     = true
    var forcePolling:          Bool     = false
    var staleSeconds:          Double   = 4.0
    var pollIntervalSeconds:   Double   = 0.5
    var progressLogThreshMB:   Double   = 100.0
    var snapshotIntervalSecs:  Double   = 30.0
    var maxRecent:             Int      = 50
    var soundEnabled:          Bool     = false

    // ── Data ───────────────────────────────────────────────────────────────
    let tracker = FileTracker()
    let logger  = FolderLogger()

    private var watcher:      FolderWatcher?
    private var staleTimer:   Timer?
    private var snapTimer:    Timer?
    private var lastSnap:     Date = .distantPast
    private let probeSem      = AsyncSemaphore(limit: 3)
    private let probeService  = AVProbeService()

    // ── Sandbox security scope ───────────────────────────────────────────────
    // The app is sandboxed, so access to a user-chosen folder does NOT survive
    // a relaunch unless we persist a security-scoped bookmark and re-assert
    // access via startAccessingSecurityScopedResource() before reading.
    private(set) var bookmarkData: Data?
    private var securityScopedURL: URL?
    private var isAccessingScopedResource = false

    // MARK: - Init

    init(path: String) {
        self.path = path
    }

    deinit {
        // Note: @MainActor deinit — timers and watcher will be cleaned up
    }

    /// Associates a security-scoped URL (from a picker/drag or a resolved
    /// bookmark) and its bookmark data so access can be re-asserted on start
    /// and persisted across launches.
    func setSecurityScope(url: URL, bookmark: Data?) {
        securityScopedURL = url
        bookmarkData      = bookmark
    }

    /// Begins sandbox access if not already held. Returns true if this call is
    /// what started it (so the caller knows it owns the balancing stop).
    @discardableResult
    private func beginScopedAccessIfNeeded() -> Bool {
        guard let url = securityScopedURL, !isAccessingScopedResource else { return false }
        isAccessingScopedResource = url.startAccessingSecurityScopedResource()
        return isAccessingScopedResource
    }

    private func endScopedAccess() {
        guard isAccessingScopedResource, let url = securityScopedURL else { return }
        url.stopAccessingSecurityScopedResource()
        isAccessingScopedResource = false
    }

    // MARK: - Control

    func start(scanExisting: Bool = true) {
        guard watcher == nil else { return }

        // Re-assert sandbox access before any filesystem reads. Without this,
        // a folder restored from a bookmark is unreadable and every scan/poll
        // silently returns nothing.
        beginScopedAccessIfNeeded()

        isWatching = true

        tracker.watchPath = path
        logger.start(label: label)
        logger.log(tag: "SESSION START", name: displayName,
                   detail: "watching \(path)")
        tracker.soundEnabled = soundEnabled

        // ── Start the watcher IMMEDIATELY so live writes are caught right away.
        // The scan runs in parallel below. The tracker's `isScanning` flag
        // makes update() ignore events for paths the scan hasn't registered
        // yet, so pre-existing files won't be mis-classified as active.
        startWatcherAndTimers()

        if scanExisting {
            Task { @MainActor in
                existingCount = await tracker.scanExisting(at: path, recursive: recursive)
                logger.log(tag: "SCAN", name: displayName,
                           detail: "found \(existingCount) existing video file(s) in \(path)")
            }
        }
    }

    /// Creates the polling watcher and stale timer.
    private func startWatcherAndTimers() {
        watcher = FolderWatcher(
            path: path,
            recursive: recursive,
            interval: pollIntervalSeconds
        ) { [weak self] p in
            self?.tracker.update(path: p)
        }

        staleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tracker.markStale(after: self?.staleSeconds ?? 4)
                await self?.tracker.scanForOpenFiles()
                self?.checkSnapshot()
            }
        }
        if let staleTimer { RunLoop.main.add(staleTimer, forMode: .common) }
    }

    /// Re-scans the folder for existing files. Safe to call while watching.
    /// Bypasses the AppSettings.shared.scanExistingOnLaunch toggle so it always runs.
    func rescan() {
        Task { @MainActor in
            // Ensure access even if the folder isn't currently watching.
            let startedHere = beginScopedAccessIfNeeded()
            existingCount = await tracker.scanExisting(at: path, recursive: recursive)
            logger.log(tag: "RESCAN", name: displayName,
                       detail: "found \(existingCount) existing video file(s) in \(path)")
            if startedHere { endScopedAccess() }
        }
    }

    func stop() {
        guard isWatching else { return }
        isWatching = false

        watcher?.stop();  watcher  = nil
        staleTimer?.invalidate(); staleTimer = nil
        snapTimer?.invalidate();  snapTimer  = nil

        endScopedAccess()

        logger.log(tag: "SESSION END", name: displayName,
                   detail: "total \(fmtSize(tracker.totalWritten))  |  \(tracker.completedPaths.count) files completed")
        logger.stop()
    }

    func reset() {
        stop()
        tracker.reset()
        existingCount = 0
        logger.clear()
    }

    // MARK: - Snapshot logging

    private func checkSnapshot() {
        guard isWatching,
              !tracker.activeEntries.isEmpty,
              Date().timeIntervalSince(lastSnap) >= snapshotIntervalSecs
        else { return }
        lastSnap = Date()
        let count = tracker.activeEntries.count
        logger.log(tag: "SNAPSHOT", name: displayName,
                   detail: "\(count) active  |  session total \(fmtSize(tracker.totalWritten))")
    }

    // MARK: - Reveal helpers

    func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    func revealLogInFinder() {
        guard let url = logger.logFileURL else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
