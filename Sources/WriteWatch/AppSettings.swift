import SwiftUI
import Foundation

/// App-wide defaults persisted in UserDefaults.
/// New WatchedFolders inherit these values at creation time.
final class AppSettings: ObservableObject {

    // MARK: - Watching
    @AppStorage("ww.staleSeconds")        var staleSeconds:        Double = 4.0
    @AppStorage("ww.pollInterval")        var pollInterval:        Double = 1.0
    @AppStorage("ww.recursive")           var recursive:           Bool   = true
    @AppStorage("ww.forcePolling")        var forcePolling:        Bool   = false

    // MARK: - Safety
    /// When true, WriteWatch never runs `lsof` and uses gentle polling only.
    /// This is the safest mode for active capture drives — it avoids any
    /// filesystem contention that could disrupt a camera writing to the volume.
    @AppStorage("ww.passiveMode")         var passiveMode:         Bool   = true

    // MARK: - Sound
    @AppStorage("ww.soundEnabled")        var soundEnabled:        Bool   = true

    // MARK: - Validation
    @AppStorage("ww.validationEnabled")   var validationEnabled:   Bool   = true
    @AppStorage("ww.maxConcurrentProbes") var maxConcurrentProbes: Int    = 3

    // MARK: - Logging
    @AppStorage("ww.progressThreshMB")   var progressThreshMB:    Double = 100.0
    @AppStorage("ww.snapshotInterval")   var snapshotInterval:    Double = 30.0
    @AppStorage("ww.defaultLabel")       var defaultLabel:        String = ""

    // MARK: - Startup
    /// Automatically begin watching all restored folders when the app launches.
    @AppStorage("ww.autoStartOnLaunch")  var autoStartOnLaunch:   Bool   = true
    /// Re-scan restored folders for existing files on launch, populating the
    /// completed list with what's already on disk (each gets re-validated).
    @AppStorage("ww.scanExistingOnLaunch") var scanExistingOnLaunch: Bool = true

    // MARK: - Display
    @AppStorage("ww.defaultMode")        var defaultMode:         String = "modern"
    @AppStorage("ww.showMidJoinBadge")   var showMidJoinBadge:    Bool   = true

    /// The Mac's name, used as the default log label. Falls back gracefully.
    static var computerName: String {
        let n = Host.current().localizedName ?? ""
        return n.isEmpty ? "WriteWatch" : n
    }

    /// On first launch (label still empty), seed it with the computer name so
    /// logs are meaningfully named even if the user never changes it.
    func seedDefaultLabelIfNeeded() {
        if defaultLabel.isEmpty {
            defaultLabel = Self.computerName
        }
    }

    static let shared = AppSettings()
    private init() {}
}
