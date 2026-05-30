import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var vm: MonitorViewModel
    @EnvironmentObject var dialogs: AppDialogs
    @State private var tick: Int = 0
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var allActive: [TaggedEntry] {
        vm.folders.flatMap { folder in
            folder.tracker.activeEntries.map {
                TaggedEntry(folderName: folder.displayName, entry: $0)
            }
        }
        .sorted { $0.entry.started < $1.entry.started }
    }

    private var allRecentCompleted: [TaggedEntry] {
        let all = vm.folders.flatMap { folder in
            folder.tracker.completedPaths
                .compactMap { folder.tracker.entries[$0] }
                .map { TaggedEntry(folderName: folder.displayName, entry: $0) }
        }
        return all.sorted {
            ($0.entry.finished ?? .distantPast) > ($1.entry.finished ?? .distantPast)
        }
    }

    var body: some View {
        ZStack {
            Color.termBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {

                    // Banner — fixed monospaced width, always full
                    BannerView(
                        tick:         tick,
                        isActive:     vm.globalActiveCount > 0,
                        watchFolders: vm.folders
                    )

                    sessionBar

                    // Tables: left-aligned, never expand beyond their
                    // natural column width. HStack + Spacer achieves this
                    // without needing to know the pixel total up front.
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            ActiveTransfersView(entries: allActive, tick: tick)
                                
                            if !allRecentCompleted.isEmpty {
                                CompletedFilesView(entries: allRecentCompleted)
                                    
                            }
                        }
                        Spacer(minLength: 0)   // push tables left; no horizontal stretch
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                // Banner is ~92 chars × 7.23 ≈ 665 px; keep at least that.
                // Tables will expand horizontally if columns are dragged wider.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbar { toolbarItems }
        .onReceive(refreshTimer) { _ in
            tick += 1
            vm.folders.forEach { $0.tracker.markStale() }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for p in providers {
                p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url  = URL(dataRepresentation: data, relativeTo: nil),
                          url.hasDirectoryPath else { return }
                    DispatchQueue.main.async { vm.addFolder(url) }
                }
            }
            return true
        }
    }

    // MARK: - Session bar

    private var sessionBar: some View {
        HStack(spacing: 0) {
            Text("░▒▓ SESSION")
                .foregroundColor(.termCyanDim)
                .fontWeight(.bold)
            Text("  total: ").foregroundColor(.termDim)
            Text(fmtSize(vm.globalTotalWritten)).foregroundColor(.termCyan)
            Text("  ·  done: ").foregroundColor(.termDim)
            Text("\(vm.globalCompletedCount)").foregroundColor(.termCyan)
            Text("  ·  folders: ").foregroundColor(.termDim)
            Text("\(vm.folders.count)").foregroundColor(.termCyan)
            Text("  ·  ").foregroundColor(.termDim)
            Text(vm.anyWatching ? "WATCHING" : "STOPPED")
                .foregroundColor(vm.anyWatching ? .termGreen : .termDim)
                .fontWeight(.bold)
            Text("  ┊  drag headers to resize")
                .foregroundColor(Color.termDim.opacity(0.4))
        }
        .font(.monoSm)
        .padding(.vertical, 2)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if vm.anyWatching {
                Button { vm.stopAll() } label: {
                    Label("Stop All", systemImage: "stop.circle.fill")
                }
                .foregroundColor(.termRed)
                .help("Stop all folders")
            } else if !vm.folders.isEmpty {
                Button { vm.startAll() } label: {
                    Label("Start All", systemImage: "play.circle.fill")
                }
                .foregroundColor(.termGreen)
                .help("Start all folders")
            }

            Button { vm.pickFolder() } label: {
                Label(vm.folders.isEmpty ? "Choose Folder" : "Add Folder",
                      systemImage: "folder.badge.plus")
            }
            .help("Add a folder to monitor")

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Preferences (⌘,)")

            // Clear actions tucked into a small menu so the toolbar stays tidy
            Menu {
                Button { vm.rescanAllFolders() } label: {
                    Label("Rescan All Folders", systemImage: "arrow.clockwise")
                }
                .disabled(vm.folders.isEmpty)

                Divider()

                Button(role: .destructive) {
                    dialogs.confirmClearHistory = true
                } label: {
                    Label("Clear Completed History…", systemImage: "trash")
                }
                .disabled(vm.globalCompletedCount == 0)

                Button(role: .destructive) {
                    dialogs.confirmClearFolders = true
                } label: {
                    Label("Remove All Folders…", systemImage: "folder.badge.minus")
                }
                .disabled(vm.folders.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .help("More actions")
        }
    }
}
