import Foundation
import AppKit

// MARK: - Sidebar selection

enum SidebarSelection: Hashable {
    case folder(UUID)
    case overview(OverviewFilter)
    case smart(SmartFilter)
}

enum OverviewFilter: String, Hashable {
    case allWriting   = "All Writing"
    case allCompleted = "All Completed"
}

enum SmartFilter: String, CaseIterable, Hashable {
    case allFiles  = "All Files"
    case writing   = "Writing"
    case completed = "Completed"
    case valid     = "Valid"
    case corrupt   = "Corrupt"

    var icon: String {
        switch self {
        case .allFiles:  return "tray.full"
        case .writing:   return "record.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .valid:     return "checkmark.seal.fill"
        case .corrupt:   return "xmark.octagon.fill"
        }
    }

    var color: String { // use string so we can reference in View layer
        switch self {
        case .allFiles:  return "blue"
        case .writing:   return "orange"
        case .completed: return "green"
        case .valid:     return "green"
        case .corrupt:   return "red"
        }
    }
}

// MARK: - BottomTab

enum BottomTab: String, CaseIterable {
    case files       = "Files"
    case activityLog = "Activity Log"
}

// MARK: - MonitorViewModel

@MainActor
final class MonitorViewModel: ObservableObject {

    @Published var folders:          [WatchedFolder] = []
    @Published var sidebarSelection: SidebarSelection?
    @Published var selectedFilePath: String?
    @Published var bottomTab:        BottomTab = .files

    // MARK: - Selected folder (from sidebar)

    var selectedFolder: WatchedFolder? {
        guard case .folder(let id) = sidebarSelection else { return nil }
        return folders.first { $0.id == id }
    }

    // MARK: - Global stats

    var globalActiveCount: Int    { folders.reduce(0) { $0 + $1.tracker.activeEntries.count } }
    var globalTotalWritten: Int64 { folders.reduce(0) { $0 + $1.tracker.totalWritten } }
    var globalCompletedCount: Int { folders.reduce(0) { $0 + $1.tracker.completedPaths.count } }
    var globalFilesCount: Int     { folders.reduce(0) { $0 + $1.tracker.entries.count } }
    var runningCount: Int         { folders.filter(\.isWatching).count }

    // MARK: - Smart folder counts

    func count(for filter: SmartFilter) -> Int {
        allEntries(for: filter).count
    }

    func count(for overview: OverviewFilter) -> Int {
        switch overview {
        case .allWriting:   return globalActiveCount
        case .allCompleted: return globalCompletedCount
        }
    }

    /// All file entries across every folder, optionally filtered.
    func allEntries(for filter: SmartFilter? = nil) -> [(folder: WatchedFolder, entry: FileEntry)] {
        var result: [(WatchedFolder, FileEntry)] = []
        for folder in folders {
            for entry in folder.tracker.entries.values {
                result.append((folder, entry))
            }
        }
        guard let f = filter else { return result }
        return result.filter { _, entry in
            switch f {
            case .allFiles:  return true
            case .writing:   return entry.status == .writing
            case .completed: return entry.status == .done
            case .valid:
                if case .valid = entry.validation { return true }
                return false
            case .corrupt:
                if case .corrupt = entry.validation { return true }
                return false
            }
        }
    }

    // MARK: - Folder management

    /// Adds a folder from a security-scoped URL (NSOpenPanel, drag-and-drop, or
    /// a resolved bookmark). `resolvedBookmark` is non-nil only on restore, where
    /// the URL came from resolving an existing bookmark; for fresh picks we mint
    /// a new bookmark so access survives the next launch.
    func addFolder(_ url: URL,
                   autoStart: Bool = true,
                   scanExisting: Bool = true,
                   resolvedBookmark: Data? = nil) {
        let path = url.path
        guard !folders.contains(where: { $0.path == path }) else {
            // Already added — just select it
            if let existing = folders.first(where: { $0.path == path }) {
                sidebarSelection = .folder(existing.id)
            }
            return
        }
        let folder = WatchedFolder(path: path)

        // Persist sandbox access via a security-scoped bookmark. Fresh picks
        // already have access (granted by the panel/drag), so we can mint one
        // now; restored folders pass the bookmark they were resolved from.
        // Hold access while minting so a stale-bookmark URL can still be encoded.
        let bookmark: Data?
        if let resolvedBookmark {
            bookmark = resolvedBookmark
        } else {
            let accessing = url.startAccessingSecurityScopedResource()
            bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        folder.setSecurityScope(url: url, bookmark: bookmark)

        // Apply app-wide defaults
        let s = AppSettings.shared
        folder.staleSeconds        = s.staleSeconds
        folder.pollIntervalSeconds = s.pollInterval
        folder.recursive           = s.recursive
        folder.forcePolling        = s.forcePolling
        folder.soundEnabled        = s.soundEnabled
        folder.progressLogThreshMB = s.progressThreshMB
        folder.snapshotIntervalSecs = s.snapshotInterval
        folder.label               = s.defaultLabel
        folders.append(folder)
        sidebarSelection = .folder(folder.id)
        selectedFilePath = nil
        if autoStart { folder.start(scanExisting: scanExisting) }
        saveFolders()
    }

    func removeFolder(_ folder: WatchedFolder) {
        folder.reset()
        folders.removeAll { $0.id == folder.id }
        if case .folder(let id) = sidebarSelection, id == folder.id {
            sidebarSelection = folders.first.map { .folder($0.id) }
            selectedFilePath = nil
        }
        saveFolders()
    }

    func startAll() { folders.forEach { $0.start() } }
    func stopAll()  { folders.forEach { $0.stop()  } }
    var anyWatching: Bool { folders.contains(where: \.isWatching) }

    // MARK: - Folder picker (shared — called from both Classic and Modern)

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles          = false
        panel.canChooseDirectories    = true
        panel.allowsMultipleSelection = true
        panel.prompt  = "Watch"
        panel.message = "Choose folder(s) to monitor for video files"
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { addFolder($0) }
    }

    // MARK: - Persistence
    //
    // The app is sandboxed, so a plain path string is NOT enough to regain
    // access after relaunch — macOS revokes folder access between sessions.
    // We persist a security-scoped bookmark per folder and resolve it on launch,
    // then re-assert access before scanning/watching.

    private static let savedBookmarksKey = "ww.watchedFolderBookmarks"

    func saveFolders() {
        let bookmarks = folders.compactMap { $0.bookmarkData }
        UserDefaults.standard.set(bookmarks, forKey: Self.savedBookmarksKey)
    }

    /// Guards against SwiftUI firing `.onAppear` more than once during launch.
    private var didRestore = false

    func restoreFolders() {
        guard !didRestore else { return }
        didRestore = true

        guard let bookmarks = UserDefaults.standard.array(forKey: Self.savedBookmarksKey) as? [Data]
        else { return }

        for data in bookmarks {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: .withSecurityScope,
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale)
            else { continue }
            // If the bookmark is stale, let addFolder mint a fresh one (passing
            // nil) once access is held; otherwise reuse the resolved bookmark.
            addFolder(url,
                      autoStart: AppSettings.shared.autoStartOnLaunch,
                      scanExisting: AppSettings.shared.scanExistingOnLaunch,
                      resolvedBookmark: isStale ? nil : data)
        }
    }

    // MARK: - Clear actions

    /// Removes ALL watched folders. Caller is responsible for confirming.
    func clearAllFolders() {
        // Snapshot first because removeFolder mutates the array
        let snapshot = folders
        snapshot.forEach { $0.stop() }
        folders.removeAll()
        sidebarSelection = nil
        selectedFilePath = nil
        saveFolders()
    }

    /// Re-scans every watched folder for existing files on disk and
    /// repopulates the completed list. Bound to the "Rescan All Folders" menu.
    func rescanAllFolders() {
        folders.forEach { $0.rescan() }
    }

    /// Clears the completed-files history on every folder, keeping the folders
    /// themselves and any active transfers untouched.
    func clearAllHistory() {
        folders.forEach { $0.tracker.clearHistory() }
    }
}
