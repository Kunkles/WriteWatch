import SwiftUI

// MARK: - TaggedEntry

struct TaggedEntry: Identifiable {
    var id: String { entry.id }
    let folderName: String
    let entry:      FileEntry
}

// MARK: - ActiveTransfersView

struct ActiveTransfersView: View {
    let entries:    [TaggedEntry]
    let tick:       Int
    @EnvironmentObject var cols: ClassicColumnState

    private var multiFolder: Bool {
        Set(entries.map(\.folderName)).count > 1
    }

    // Total pixel width of all visible column cells — used to size the box.
    var totalWidth: CGFloat {
        (multiFolder ? cols.folder + charW : 0)   // +1 handle char
        + cols.filename + charW
        + cols.size     + charW
        + cols.rate     + charW
        + cols.peak     + charW
        + cols.elapsed  + charW
        + cols.status
        + 4   // left indent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                label:    "ACTIVE TRANSFERS",
                trailing: "\(nowTime()) · \(entries.isEmpty ? "idle" : "\(entries.count) xfer")"
            )
            .frame(width: totalWidth)      // match the box width exactly

            RetroBox(
                title:    "TRANSFERS",
                subtitle: entries.isEmpty ? "no active transfers" : "\(entries.count) active",
                color:    .termCyan,
                width:    totalWidth
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    Divider().background(Color.termCyanDim.opacity(0.35))
                        .frame(width: totalWidth)

                    if entries.isEmpty {
                        Text("  ·· no active transfers ·· ")
                            .font(.mono)
                            .foregroundColor(.termDim)
                            .italic()
                            .padding(.vertical, 6)
                    } else {
                        ForEach(entries) { tagged in
                            ActiveTransferRow(tagged: tagged, tick: tick, multiFolder: multiFolder)
                                .environmentObject(cols)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header with drag handles

    private var headerRow: some View {
        HStack(spacing: 0) {
            if multiFolder {
                Text("FOLDER").frame(width: cols.folder, alignment: .leading)
                dragHandle(\.folder)
            }
            Text("FILENAME").frame(width: cols.filename, alignment: .leading)
            dragHandle(\.filename)
            Text("SIZE").frame(width: cols.size, alignment: .trailing)
            dragHandle(\.size)
            Text("RATE").frame(width: cols.rate, alignment: .trailing)
            dragHandle(\.rate)
            Text("PEAK").frame(width: cols.peak, alignment: .trailing)
            dragHandle(\.peak)
            Text("ELAPSED").frame(width: cols.elapsed, alignment: .trailing)
            dragHandle(\.elapsed)
            Text("STATUS").frame(width: cols.status, alignment: .center)
        }
        .font(.monoHdr)
        .foregroundColor(.termCyan)
        .padding(.vertical, 2)
    }

    private func dragHandle(_ kp: ReferenceWritableKeyPath<ClassicColumnState, CGFloat>) -> some View {
        ResizeHandle()
            .gesture(DragGesture(minimumDistance: 2).onChanged { v in
                cols[keyPath: kp] = cols.clamp(cols[keyPath: kp] + v.translation.width)
            })
    }
}

// MARK: - ActiveTransferRow

struct ActiveTransferRow: View {
    let tagged:      TaggedEntry
    let tick:        Int
    let multiFolder: Bool
    @EnvironmentObject var cols: ClassicColumnState

    private var entry:   FileEntry    { tagged.entry }
    private var elapsed: TimeInterval { Date().timeIntervalSince(entry.started) }

    var body: some View {
        HStack(spacing: 0) {
            if multiFolder {
                Text(tagged.folderName)
                    .frame(width: cols.folder, alignment: .leading)
                    .lineLimit(1).truncationMode(.tail)
                    .foregroundColor(Color.termCyan.opacity(0.75))
                Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            }
            Text(entry.name)
                .frame(width: cols.filename, alignment: .leading)
                .lineLimit(1).truncationMode(.middle)
                .foregroundColor(.termWhite)
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(fmtSize(entry.size))
                .frame(width: cols.size, alignment: .trailing)
                .foregroundColor(.termGreen).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Group {
                if entry.rate > 0 {
                    Text(fmtRate(entry.rate)).foregroundColor(.termYellow)
                } else {
                    Text("—").foregroundColor(.termDim)
                }
            }
            .frame(width: cols.rate, alignment: .trailing).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(entry.peakRate > 0 ? fmtRate(entry.peakRate) : "—")
                .frame(width: cols.peak, alignment: .trailing)
                .foregroundColor(Color.termYellow.opacity(0.6)).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(fmtDur(elapsed))
                .frame(width: cols.elapsed, alignment: .trailing)
                .foregroundColor(.termCyan).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            statusCell.frame(width: cols.status, alignment: .center)
        }
        .font(.mono)
        .padding(.vertical, 3)
        .transaction { $0.animation = nil }
    }

    private var statusCell: some View {
        HStack(spacing: 3) {
            if entry.rate > 0 {
                Text(spinnerChar(tick: tick))
                    .frame(width: charW, alignment: .center)
                Text("WRITING").foregroundColor(.termRed).fontWeight(.bold)
            } else if entry.status == .writing {
                Text("·").frame(width: charW, alignment: .center).foregroundColor(.termDim)
                Text("IDLE   ").foregroundColor(.termDim)
            } else {
                Text(" ").frame(width: charW)
                Text("DONE   ").foregroundColor(.termDim)
            }
        }
    }
}
