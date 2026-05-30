import SwiftUI

struct ModernView: View {
    @EnvironmentObject var vm: MonitorViewModel

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            // ── Sidebar ────────────────────────────────────────────────────
            ModernSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)

        } content: {

            // ── Center: file table ─────────────────────────────────────────
            if vm.folders.isEmpty {
                emptyState
            } else {
                let folder = vm.selectedFolder   // nil for smart/overview selections
                ModernFileTableView(folder: folder)
                    .navigationTitle(centerTitle)
                    .navigationSubtitle(centerSubtitle)
                    .toolbar { centerToolbar }
            }

        } detail: {

            // ── Inspector ──────────────────────────────────────────────────
            ModernInspectorView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .navigationTitle("Inspector")

        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: vm.sidebarSelection) { _, _ in vm.selectedFilePath = nil }
        .onReceive(refreshTimer) { _ in
            vm.objectWillChange.send()
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

    // MARK: - Center toolbar (matches screenshot: play + folder name + status + label badge)

    @ToolbarContentBuilder
    private var centerToolbar: some ToolbarContent {
        // Left side: play/stop + folder pill
        ToolbarItemGroup(placement: .navigation) {
            if let folder = vm.selectedFolder {
                Button {
                    folder.isWatching ? folder.stop() : folder.start()
                } label: {
                    Image(systemName: folder.isWatching ? "stop.fill" : "play.fill")
                        .foregroundStyle(folder.isWatching ? .red : .green)
                }
                .help(folder.isWatching ? "Stop watching" : "Start watching")

                // Blue folder name pill (matches screenshot)
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                    Text(folder.displayName)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.18), in: Capsule())
                .foregroundStyle(.blue)
            }
        }

        // Right side: folder label tag + settings + remove
        ToolbarItemGroup(placement: .primaryAction) {
            if let folder = vm.selectedFolder {
                // Label badge (like "Stage01" in the screenshot)
                if !folder.label.isEmpty {
                    Text(folder.label)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Preferences (⌘,)")

                Button(role: .destructive) { vm.removeFolder(folder) } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Remove this folder")
            } else {
                Button { vm.pickFolder() } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Preferences (⌘,)")
            }
        }
    }

    // MARK: - Computed title/subtitle for center column

    private var centerTitle: String {
        switch vm.sidebarSelection {
        case .folder:                    return vm.selectedFolder?.displayName ?? "Files"
        case .overview(let f):           return f.rawValue
        case .smart(let f):              return f.rawValue
        case nil:                        return "Files"
        }
    }

    private var centerSubtitle: String {
        switch vm.sidebarSelection {
        case .folder:          return vm.selectedFolder?.path ?? ""
        case .overview, .smart: return "\(vm.folders.count) folder\(vm.folders.count == 1 ? "" : "s")"
        case nil:              return ""
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No folders added")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add a folder to start monitoring video file transfers.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Add Folder") { vm.pickFolder() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("WriteWatch")
    }
}

// MARK: - WatchedFolder: Hashable (needed for sheet(item:))

extension WatchedFolder: Hashable {
    nonisolated static func == (lhs: WatchedFolder, rhs: WatchedFolder) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
