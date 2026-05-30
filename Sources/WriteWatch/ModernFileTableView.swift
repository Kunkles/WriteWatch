import SwiftUI

// MARK: - ModernFileTableView
// Handles both per-folder and cross-folder (smart/overview) file displays.

struct ModernFileTableView: View {
    @EnvironmentObject var vm: MonitorViewModel

    // Per-folder mode
    var folder: WatchedFolder?

    @State private var sortOrder = [KeyPathComparator(\FileEntry.started, order: .reverse)]
    @State private var searchText = ""

    private var displayEntries: [FileEntry] {
        let raw: [FileEntry]
        if let f = folder {
            raw = Array(f.tracker.entries.values)
        } else {
            // Smart / overview selection — gather from all folders
            raw = smartEntries()
        }
        let filtered = searchText.isEmpty ? raw :
            raw.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        return filtered.sorted(using: sortOrder)
    }

    private func smartEntries() -> [FileEntry] {
        switch vm.sidebarSelection {
        case .overview(let f):
            return vm.allEntries(for: nil)
                .filter { _, e in
                    f == .allWriting ? e.status == .writing : e.status == .done
                }.map(\.entry)
        case .smart(let f):
            return vm.allEntries(for: f).map(\.entry)
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            fileTable
            Divider()
            bottomTabBar
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter files")
    }

    // MARK: - Table

    private var fileTable: some View {
        Group {
            switch vm.bottomTab {
            case .files:
                Table(displayEntries, selection: $vm.selectedFilePath, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name) { e in
                        HStack(spacing: 6) { statusDot(e); Text(e.name).lineLimit(1) }
                    }
                    .width(min: 160, ideal: 220)

                    TableColumn("Size", value: \.size) { e in
                        Text(fmtSize(e.size)).monospacedDigit()
                            .foregroundStyle(e.status == .writing ? .primary : .secondary)
                    }
                    .width(80)

                    TableColumn("Rate", value: \.rate) { e in
                        if e.status == .writing && e.rate > 0 {
                            Text(fmtRate(e.rate)).monospacedDigit().foregroundStyle(.orange)
                        } else { Text("—").foregroundStyle(.tertiary) }
                    }
                    .width(80)

                    TableColumn("Peak", value: \.peakRate) { e in
                        Text(e.peakRate > 0 ? fmtRate(e.peakRate) : "—")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .width(80)

                    TableColumn("Duration", value: \.started) { e in
                        if e.status == .writing {
                            Text(fmtDur(Date().timeIntervalSince(e.started)))
                                .monospacedDigit().foregroundStyle(.secondary)
                        } else if let d = e.duration {
                            Text(fmtDur(d))
                                .monospacedDigit()
                                .foregroundStyle(durationColor(e))
                                .fontWeight(durationWeight(e))
                        } else if e.validation == .checking {
                            Text("···").foregroundStyle(.tertiary)
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
                    }
                    .width(80)

                    TableColumn("Status", value: \.status.sortKey) { e in
                        statusBadge(e)
                    }
                    .width(90)

                    TableColumn("Validation") { e in
                        validationCell(e)
                    }
                    .width(min: 100, ideal: 160)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))

            case .activityLog:
                if let f = folder {
                    LogPaneView(logger: f.logger)
                } else {
                    Text("Select a specific folder to view its activity log.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Bottom tab bar (matches screenshot — plain text buttons)

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BottomTab.allCases, id: \.self) { tab in
                Button {
                    vm.bottomTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundStyle(vm.bottomTab == tab ? .primary : .secondary)
                        .background(
                            vm.bottomTab == tab
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right status: observer type + bytes written
            if let f = folder {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                    Text(f.forcePolling ? "Polling" : "FSEvents")
                        .foregroundStyle(.secondary)
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                    Text(fmtSize(f.tracker.totalWritten))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let free = f.freeSpace {
                        Text("·").foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: diskSpaceIsCritical(free)
                                  ? "externaldrive.badge.exclamationmark"
                                  : "externaldrive.badge.checkmark")
                                .foregroundStyle(diskBarColor(f))
                            Text("\(fmtSize(free)) free")
                                .monospacedDigit()
                                .foregroundStyle(diskBarColor(f))
                        }
                        .blink(diskSpaceIsCritical(free))
                    }
                }
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Cell helpers

    @ViewBuilder
    private func statusDot(_ e: FileEntry) -> some View {
        Circle()
            .fill(e.status == .writing && e.rate > 0 ? Color.orange :
                  e.status == .writing ? Color.yellow : Color.secondary.opacity(0.3))
            .frame(width: 7, height: 7)
    }

    @ViewBuilder
    private func statusBadge(_ e: FileEntry) -> some View {
        switch e.status {
        case .writing:
            Label(e.rate > 0 ? "Writing" : "Idle",
                  systemImage: e.rate > 0 ? "record.circle.fill" : "pause.circle")
                .foregroundStyle(e.rate > 0 ? .orange : .secondary).font(.caption)
        case .done:
            Label("Done", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary).font(.caption)
        }
    }

    @ViewBuilder
    private func validationCell(_ e: FileEntry) -> some View {
        switch e.validation {
        case .none:
            if e.status == .done { Text("—").foregroundStyle(.tertiary).font(.caption) }
        case .checking:
            Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary).font(.caption)
        case .valid(let d):
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Label("Valid", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green).font(.caption.bold())
                    if e.isVFR {
                        Text("VFR")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .help("Variable frame rate")
                    }
                }
                HStack(spacing: 4) {
                    if !d.isEmpty {
                        Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let fps = e.frameRate {
                        Text(fmtFrameRate(fps))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        case .corrupt(let d):
            VStack(alignment: .leading, spacing: 1) {
                Label("Corrupt", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red).font(.caption.bold())
                HStack(spacing: 4) {
                    if !d.isEmpty {
                        Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let fps = e.frameRate {
                        Text(fmtFrameRate(fps))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        case .stillOpen:
            Label("Still Open", systemImage: "exclamationmark.octagon")
                .foregroundStyle(.yellow).font(.caption)
        case .noProbe:
            Label("No probe", systemImage: "questionmark.circle")
                .foregroundStyle(.tertiary).font(.caption)
        }
    }

    // Duration accuracy coloring (matches the Classic view logic)
    private func durationColor(_ e: FileEntry) -> Color {
        switch e.durationMatch {
        case .imported: return .purple
        case .exact:    return .green
        case .close:    return .yellow
        case .off:      return .red
        case .unknown:  return .secondary
        }
    }

    private func durationWeight(_ e: FileEntry) -> Font.Weight {
        switch e.durationMatch {
        case .exact, .off: return .bold
        default:           return .regular
        }
    }

    private func diskBarColor(_ f: WatchedFolder) -> Color {
        guard let free = f.freeSpace else { return .secondary }
        return diskSpaceColor(free)
    }
}

extension FileStatus {
    var sortKey: String { self == .writing ? "a" : "b" }
}
