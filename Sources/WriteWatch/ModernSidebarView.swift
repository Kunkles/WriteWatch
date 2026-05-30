import SwiftUI

struct ModernSidebarView: View {
    @EnvironmentObject var vm: MonitorViewModel
    @EnvironmentObject var dialogs: AppDialogs

    var body: some View {
        List(selection: $vm.sidebarSelection) {
            // ── App header ─────────────────────────────────────────────────
            appHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 8, leading: 12, bottom: 4, trailing: 12))

            // ── Inline toolbar row ────────────────────────────────────────
            HStack(spacing: 8) {
                // Master play/stop
                if !vm.folders.isEmpty {
                    Button {
                        vm.anyWatching ? vm.stopAll() : vm.startAll()
                    } label: {
                        Label(
                            vm.anyWatching ? "Stop All" : "Start All",
                            systemImage: vm.anyWatching ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .foregroundStyle(vm.anyWatching ? Color.red : Color.green)
                    }
                    .buttonStyle(.plain)
                    .help(vm.anyWatching ? "Stop all folders" : "Start all folders")
                }
                Spacer()
                Button { vm.pickFolder() } label: {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add folder")

                // Overflow menu for destructive actions
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
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
                .help("More actions")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 8, bottom: 0, trailing: 8))

            // ── Watched Folders ────────────────────────────────────────────
            Section("Watched Folders") {
                ForEach(vm.folders) { folder in
                    FolderSidebarRow(folder: folder)
                        .tag(SidebarSelection.folder(folder.id))
                        .contextMenu { folderContextMenu(folder) }
                }
                // Add Folder button as a list row
                Button {
                    vm.pickFolder()
                } label: {
                    Label("Add Folder…", systemImage: "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
            }

            // ── Overview ───────────────────────────────────────────────────
            Section("Overview") {
                overviewRow(
                    label: "All Writing",
                    icon: "record.circle.fill",
                    color: .orange,
                    filter: .allWriting
                )
                overviewRow(
                    label: "All Completed",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    filter: .allCompleted
                )
            }

            // ── Smart Folders ──────────────────────────────────────────────
            Section("Smart Folders") {
                ForEach(SmartFilter.allCases, id: \.self) { filter in
                    smartRow(filter: filter)
                        .tag(SidebarSelection.smart(filter))
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - App header

    private var appHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Branding row
            HStack(spacing: 10) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Watch Writes")
                        .font(.headline)
                    Text("\(vm.folders.count) location\(vm.folders.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statCell(value: "\(vm.globalFilesCount)", label: "files")
                Divider().frame(height: 28)
                statCell(value: "\(vm.globalActiveCount)", label: "active")
                Divider().frame(height: 28)
                statCell(value: fmtSize(vm.globalTotalWritten), label: "written")
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(value == "0" ? .secondary : .primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Overview rows

    private func overviewRow(label: String, icon: String, color: Color, filter: OverviewFilter) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            let c = vm.count(for: filter)
            if c > 0 {
                Text("\(c)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .tag(SidebarSelection.overview(filter))
    }

    // MARK: - Smart folder rows

    private func smartRow(filter: SmartFilter) -> some View {
        HStack {
            Label(filter.rawValue, systemImage: filter.icon)
                .foregroundStyle(smartColor(filter))
            Spacer()
            let c = vm.count(for: filter)
            Text("\(c)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(c > 0 ? .secondary : .tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }

    private func smartColor(_ f: SmartFilter) -> Color {
        switch f {
        case .allFiles:  return .blue
        case .writing:   return .orange
        case .completed: return .green
        case .valid:     return .green
        case .corrupt:   return .red
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func folderContextMenu(_ folder: WatchedFolder) -> some View {
        if folder.isWatching {
            Button("Stop This Folder") { folder.stop() }
        } else {
            Button("Start This Folder") { folder.start() }
        }
        Divider()
        Button("Reveal in Finder") { folder.revealInFinder() }
        if folder.logger.logFileURL != nil {
            Button("Reveal Log File in Finder") { folder.revealLogInFinder() }
        }
        Divider()
        Button("Remove", role: .destructive) { vm.removeFolder(folder) }
    }
}

// MARK: - FolderSidebarRow

struct FolderSidebarRow: View {
    @ObservedObject var folder: WatchedFolder

    var body: some View {
        HStack(spacing: 10) {
            // Folder icon
            Image(systemName: "folder.fill")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 28)

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(folder.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // File count
            Text("\(folder.tracker.entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            // Play/Stop button
            Button {
                folder.isWatching ? folder.stop() : folder.start()
            } label: {
                Image(systemName: folder.isWatching
                      ? "stop.circle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(folder.isWatching ? .red : .green)
            }
            .buttonStyle(.plain)
            .symbolEffect(.pulse, isActive: folder.tracker.hasActiveTransfers)
        }
        .padding(.vertical, 2)
    }
}
