import SwiftUI

// MARK: - Inspector root — switches between folder and file mode

struct ModernInspectorView: View {
    @EnvironmentObject var vm: MonitorViewModel

    var body: some View {
        if let path   = vm.selectedFilePath,
           let folder = vm.selectedFolder,
           let entry  = folder.tracker.entries[path] {
            FileInspectorView(entry: entry)
        } else if let folder = vm.selectedFolder {
            FolderInspectorView(folder: folder)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Select a folder or file")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Folder inspector (matches screenshot)

struct FolderInspectorView: View {
    @EnvironmentObject var vm: MonitorViewModel
    @ObservedObject var folder: WatchedFolder

    var body: some View {
        List {
            // Title
            Section {
                Text(folder.displayName)
                    .font(.title3.bold())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Location
            Section("Location") {
                inspRow(label: "Path",      value: folder.path)
                inspRow(label: "Observer",  value: folder.forcePolling ? "Polling" : "FSEvents")
                inspRow(label: "Recursive", value: folder.recursive ? "Yes" : "No")
            }

            // Storage
            Section("Storage") {
                if let free = folder.freeSpace {
                    HStack {
                        Text("Free space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(fmtSize(free))
                            .font(.caption.bold())
                            .foregroundStyle(diskColor)
                        if diskSpaceIsCritical(free) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .blink(folder.freeSpace.map(diskSpaceIsCritical) ?? false)
                }
                if let total = folder.totalSpace {
                    inspRow(label: "Total", value: fmtSize(total))
                }
                if let used = folder.usedFraction {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .leading)
                            Text("\(Int(used * 100))%")
                                .font(.caption)
                                .foregroundStyle(diskColor)
                            Spacer()
                        }
                        ProgressView(value: used)
                            .progressViewStyle(.linear)
                            .tint(diskColor)
                    }
                }
            }

            // App
            Section("App") {
                inspRow(label: "Version",    value: "1.8.4-beta")
                HStack {
                    Text("Validation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("AVFoundation")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // This session
            Section("This session") {
                inspRow(label: "Files seen",    value: "\(folder.tracker.entries.count)")
                inspRow(label: "Active",        value: "\(folder.tracker.activeEntries.count)")
                inspRow(label: "Completed",     value: "\(folder.tracker.completedPaths.count)")
                inspRow(label: "Bytes written", value: fmtSize(folder.tracker.totalWritten))
            }

            // All folders (global)
            Section("All folders") {
                inspRow(label: "Locations", value: "\(vm.folders.count)")
                inspRow(label: "Running",   value: "\(vm.runningCount)")
            }
        }
        .listStyle(.inset)
    }

    private func inspRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
            Spacer()
        }
    }

    // Color by absolute free space remaining:
    //   > 1 TB  green · > 500 GB yellow · > 200 GB orange · ≤ 100 GB red
    private var diskColor: Color {
        guard let free = folder.freeSpace else { return .secondary }
        return diskSpaceColor(free)
    }
}

// MARK: - File inspector

struct FileInspectorView: View {
    let entry: FileEntry

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: fileIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(fileIconColor)
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(3)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Info") {
                inspRow("Name",  entry.name)
                inspRow("Path",  entry.path)
                inspRow("Size",  fmtSize(entry.size))
            }

            Section("Status") {
                inspRow("State",    statusLabel)
                inspRow("Events",   "\(entry.events) seen")
                inspRow("Started",  formatDate(entry.started))
                if let d = entry.duration { inspRow("Duration", fmtDur(d)) }
                if entry.peakRate > 0     { inspRow("Peak Rate", fmtRate(entry.peakRate)) }
            }

            Section("Validation") {
                switch entry.validation {
                case .none:
                    inspRow("Result", entry.status == .done ? "Pending" : "—")
                case .checking:
                    inspRow("Result", "Checking…")
                case .valid(let d):
                    inspRow("Result", "Valid ✓")
                    if !d.isEmpty { inspRow("Codecs", d) }
                case .corrupt(let d):
                    inspRow("Result", "Corrupt ✗")
                    if !d.isEmpty { inspRow("Detail", d) }
                case .stillOpen:
                    inspRow("Result", "Still Open ⚠")
                case .noProbe:
                    inspRow("Result", "Not available")
                }
            }
        }
        .listStyle(.inset)
    }

    private func inspRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private var fileIcon: String {
        switch entry.validation {
        case .valid:     return "checkmark.seal.fill"
        case .corrupt:   return "xmark.octagon.fill"
        case .stillOpen: return "exclamationmark.octagon"
        default: return entry.status == .writing ? "record.circle.fill" : "doc.fill"
        }
    }

    private var fileIconColor: Color {
        switch entry.validation {
        case .valid:     return .green
        case .corrupt:   return .red
        case .stillOpen: return .yellow
        default: return entry.status == .writing ? .orange : .secondary
        }
    }

    private var statusLabel: String {
        switch entry.status {
        case .writing: return entry.rate > 0 ? "Writing" : "Idle"
        case .done:    return entry.isPreExisting ? "Pre-existing" : "Completed"
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }
}
