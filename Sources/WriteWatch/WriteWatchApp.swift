import SwiftUI
import AppKit

@main
struct WriteWatchApp: App {
    @StateObject private var monitorVM = MonitorViewModel()
    @StateObject private var settings  = AppSettings.shared

    // Used to surface confirmation alerts from menu commands. RootView observes
    // these and presents the appropriate alert.
    @StateObject private var dialogs = AppDialogs.shared

    // Intercept app termination to ask for confirmation.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(monitorVM)
                .environmentObject(settings)
                .environmentObject(dialogs)
                .preferredColorScheme(.dark)
                .onAppear {
                    settings.seedDefaultLabelIfNeeded()
                    appDelegate.monitorVM = monitorVM
                    // Defer restore one run-loop tick so the window's run loop is
                    // fully up before watcher timers are scheduled. Restoring
                    // during the first onAppear pass could leave a folder
                    // added-but-not-actually-watching.
                    DispatchQueue.main.async {
                        monitorVM.restoreFolders()
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // File menu additions
            CommandGroup(after: .newItem) {
                Button("Add Folder…") { monitorVM.pickFolder() }
                    .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("Clear All Folders…") {
                    dialogs.confirmClearFolders = true
                }
                .disabled(monitorVM.folders.isEmpty)

                Button("Clear Completed History…") {
                    dialogs.confirmClearHistory = true
                }
                .disabled(monitorVM.globalCompletedCount == 0)

                Divider()

                Button("Rescan All Folders") {
                    monitorVM.rescanAllFolders()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(monitorVM.folders.isEmpty)
            }
        }

        Settings {
            AppSettingsView()
        }
    }
}

// MARK: - AppDialogs
//
// Lightweight observable that lets menu commands trigger alerts in the main
// window. SwiftUI menu actions can't present alerts directly, so we toggle
// these flags and the RootView's .alert modifiers do the actual presentation.

@MainActor
final class AppDialogs: ObservableObject {
    static let shared = AppDialogs()
    @Published var confirmClearFolders = false
    @Published var confirmClearHistory = false
    private init() {}
}

// MARK: - AppDelegate
//
// Used for two things:
//   1) Save folder list on every quit (belt-and-suspenders alongside the
//      save-on-modify in MonitorViewModel).
//   2) Show a quit-confirmation dialog when transfers are active.

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var monitorVM: MonitorViewModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Always persist before quitting
        monitorVM?.saveFolders()

        // If anything is actively writing, confirm before quitting
        let activeCount = monitorVM?.globalActiveCount ?? 0
        guard activeCount > 0 else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit WriteWatch while \(activeCount) transfer\(activeCount == 1 ? " is" : "s are") active?"
        alert.informativeText = "Quitting now means WriteWatch will stop tracking the in-progress write\(activeCount == 1 ? "" : "s"). The recorded files won't be affected — only the monitoring stops."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
