import SwiftUI
import AppKit

enum AppViewMode: String, CaseIterable {
    case classic = "Classic"
    case modern  = "Modern"
    var icon: String {
        switch self {
        case .classic: return "text.alignleft"
        case .modern:  return "square.grid.2x2"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var vm:       MonitorViewModel
    @EnvironmentObject var dialogs:  AppDialogs
    @StateObject private var colState  = ClassicColumnState()
    @StateObject private var winMgr    = WindowSizeManager()

    @State private var mode: AppViewMode = AppSettings.shared.defaultMode == "classic" ? .classic : .modern
    @State private var defaultsSet = false

    var body: some View {
        Group {
            switch mode {
            case .classic:
                ContentView()
                    .environmentObject(colState)
            case .modern:
                ModernView()
            }
        }
        // Invisible view that gives us NSWindow access on first appear
        .background(
            WindowAccessor { window in
                guard !self.defaultsSet else { return }
                self.defaultsSet = true

                // Set default widths on very first launch
                self.winMgr.setDefaultsIfNeeded(
                    classicTableWidth: self.colState.defaultTableWidth
                )

                // Apply the stored width for the initial mode right away
                // (small delay so the window is fully ready)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.winMgr.applyWidth(for: self.mode)
                }

                // Observe column reset notification from Settings
                NotificationCenter.default.addObserver(
                    forName: .resetClassicColumns,
                    object: nil,
                    queue: .main
                ) { _ in
                    self.colState.filename = 200
                    self.colState.size     = 80
                    self.colState.rate     = 95
                    self.colState.peak     = 95
                    self.colState.elapsed  = 72
                    self.colState.status   = 90
                    self.colState.validCol = 260
                    self.colState.folder   = 110
                }

                // Observe window resize so we can save the new width
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        self.winMgr.recordWidth(for: self.mode)
                    }
                }
            }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("View", selection: $mode) {
                    ForEach(AppViewMode.allCases, id: \.self) { m in
                        Label(m.rawValue, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .help("Switch between Classic terminal view and Modern dashboard")
            }
        }
        .onChange(of: mode) { oldMode, newMode in
            // Save the width we're leaving, then animate to the new mode's width
            winMgr.recordWidth(for: oldMode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                winMgr.applyWidth(for: newMode)
            }
        }
        // ── Confirmation alerts (triggered from File menu commands) ─────────
        .alert(
            "Remove all watched folders?",
            isPresented: $dialogs.confirmClearFolders
        ) {
            Button("Remove All", role: .destructive) {
                vm.clearAllFolders()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This stops monitoring \(vm.folders.count) folder\(vm.folders.count == 1 ? "" : "s") and clears their history. The recorded files on disk are not touched.")
        }
        .alert(
            "Clear completed history?",
            isPresented: $dialogs.confirmClearHistory
        ) {
            Button("Clear History", role: .destructive) {
                vm.clearAllHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes \(vm.globalCompletedCount) completed file\(vm.globalCompletedCount == 1 ? "" : "s") from the display and resets session totals. Active transfers and watched folders are kept. The actual files on disk are not touched.")
        }
    }
}
