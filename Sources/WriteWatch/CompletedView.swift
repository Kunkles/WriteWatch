import SwiftUI

struct CompletedFilesView: View {
    let entries: [TaggedEntry]
    @EnvironmentObject var cols: ClassicColumnState

    private var multiFolder: Bool {
        Set(entries.map(\.folderName)).count > 1
    }

    var totalWidth: CGFloat {
        (multiFolder ? cols.folder + charW : 0)
        + cols.filename + charW
        + cols.size     + charW
        + cols.peak     + charW
        + cols.elapsed  + charW
        + cols.validCol
        + 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(label: "COMPLETED FILES", trailing: "\(entries.count) shown")
                .foregroundColor(.termDimMid)
                .frame(width: totalWidth)

            RetroBox(
                title:    "COMPLETED",
                subtitle: "\(entries.count) files",
                color:    .termDim,
                width:    totalWidth
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    Divider().background(Color.termDim.opacity(0.35))
                        .frame(width: totalWidth)
                    ForEach(entries) { tagged in
                        CompletedRow(tagged: tagged, multiFolder: multiFolder)
                            .environmentObject(cols)
                        if tagged.id != entries.last?.id {
                            Divider().background(Color.termDim.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            if multiFolder {
                Text("FOLDER").frame(width: cols.folder, alignment: .leading)
                dragHandle(\.folder)
            }
            Text("FILENAME").frame(width: cols.filename, alignment: .leading)
            dragHandle(\.filename)
            Text("FINAL SIZE").frame(width: cols.size, alignment: .trailing)
            dragHandle(\.size)
            Text("PEAK RATE").frame(width: cols.peak, alignment: .trailing)
            dragHandle(\.peak)
            Text("DURATION").frame(width: cols.elapsed, alignment: .trailing)
            dragHandle(\.elapsed)
            Text("VALIDATION").frame(width: cols.validCol, alignment: .leading).padding(.leading, 6)
            dragHandle(\.validCol)
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

struct CompletedRow: View {
    let tagged:      TaggedEntry
    let multiFolder: Bool
    @EnvironmentObject var cols: ClassicColumnState

    private var entry: FileEntry { tagged.entry }

    private var durationStr: String {
        if let d = entry.duration { return fmtDur(d) }
        if entry.validation == .checking { return "···" }
        return "—"
    }

    // Color the duration based on how well recording time matches media length.
    private var durationColor: Color {
        switch entry.durationMatch {
        case .imported: return Color.termMagenta              // purple — imported
        case .exact:    return Color.termGreen                // bright green — spot on
        case .close:    return Color.termYellow               // yellow — slightly off
        case .off:      return Color.termRed                  // red — way off
        case .unknown:  return Color.termCyan.opacity(0.55)   // neutral
        }
    }

    private var durationWeight: Font.Weight {
        switch entry.durationMatch {
        case .exact, .off: return .bold
        default:           return .regular
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if multiFolder {
                Text(tagged.folderName)
                    .frame(width: cols.folder, alignment: .leading)
                    .lineLimit(1).truncationMode(.tail)
                    .foregroundColor(Color.termCyan.opacity(0.6))
                Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            }
            Text(entry.name)
                .frame(width: cols.filename, alignment: .leading)
                .lineLimit(1).truncationMode(.middle)
                .foregroundColor(.termDimMid)
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(fmtSize(entry.size))
                .frame(width: cols.size, alignment: .trailing)
                .foregroundColor(Color.termGreen.opacity(0.65)).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(entry.peakRate > 0 ? fmtRate(entry.peakRate) : "—")
                .frame(width: cols.peak, alignment: .trailing)
                .foregroundColor(Color.termYellow.opacity(0.55)).monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            Text(durationStr)
                .frame(width: cols.elapsed, alignment: .trailing)
                .foregroundColor(durationColor)
                .fontWeight(durationWeight)
                .monospacedDigit()
            Text("┊").font(.mono).foregroundColor(Color.termDim.opacity(0.3))
            validationCell
                .frame(width: cols.validCol, alignment: .leading)
                .padding(.leading, 6)
        }
        .font(.mono)
        .padding(.vertical, 3)
        .transaction { $0.animation = nil }
    }

    private var validationCell: some View {
        let v = entry.validation
        return HStack(spacing: 6) {
            if entry.isVFR {
                Text("VFR")
                    .fontWeight(.bold)
                    .foregroundColor(.termOrange)
                    .help("Variable frame rate detected")
            }
            // Mid-join badge — honest about partial observation
            if entry.isMidJoin {
                Text("⟳")
                    .foregroundColor(Color.termOrange.opacity(0.8))
                    .help("Joined mid-write — size reflects bytes seen after folder was added")
            }
            Text(v.symbol).foregroundColor(v.color)
                .fontWeight(v == .none || v == .checking ? .regular : .bold)
            if !v.detail.isEmpty {
                Text(v.detail).foregroundColor(v.color.opacity(0.75))
                    .lineLimit(1).truncationMode(.tail)
            }
            // Embedded frame rate
            if let fps = entry.frameRate {
                Text(fmtFrameRate(fps))
                    .foregroundColor(Color.termCyan.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}
