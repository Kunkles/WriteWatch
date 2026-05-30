import SwiftUI

// MARK: - Banner rows

private let bannerRows: [String] = [
    "  ██╗    ██╗██████╗ ██╗████████╗███████╗    ██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗",
    "  ██║    ██║██╔══██╗██║╚══██╔══╝██╔════╝    ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║",
    "  ██║ █╗ ██║██████╔╝██║   ██║   █████╗      ██║ █╗ ██║███████║   ██║   ██║     ███████║",
    "  ██║███╗██║██╔══██╗██║   ██║   ██╔══╝      ██║███╗██║██╔══██║   ██║   ██║     ██╔══██║",
    "  ╚███╔███╔╝██║  ██║██║   ██║   ███████╗    ╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║",
    "   ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝    ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝",
]

private let taglineVersion = "v1.8.4-beta"
private let taglineText    = "··  real-time video transfer monitor  ··"

// Scanline cycle: rows + generous pause at the bottom before looping.
// Total cycle duration in seconds.
private let cycleDuration: Double = 1.8

// MARK: - BannerView

struct BannerView: View {
    let tick:         Int           // slow UI tick — used for rainbow offset only
    let isActive:     Bool
    let watchFolders: [WatchedFolder]

    var body: some View {
        // ASCII logo = 6 rows at 11pt monospace (~13.2pt line height each).
        // Lock the image to that exact height so it always matches the logo.
        let logoHeight: CGFloat = 6 * 13.2

        return VStack(alignment: .leading, spacing: 0) {
            // Top row: logo + tagline on the left, image locked to the right.
            // The image is a sibling of ONLY the logo block, so it stays
            // docked to the logo no matter how many watch rows appear below.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    if isActive {
                        TimelineView(.animation) { context in
                            logoRows(date: context.date)
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 2.0)) { context in
                            logoRows(date: context.date)
                        }
                    }
                    taglineBox
                }

                Image("ClassicLogo")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: logoHeight)

                Spacer(minLength: 0)
            }

            // Watch section sits below the logo+image row, full width.
            watchSection
        }
    }

    // MARK: - Logo

    private func logoRows(date: Date) -> some View {
        // Continuous time → fractional row position.
        // fmod ensures smooth wrap-around with no jump.
        let t        = date.timeIntervalSinceReferenceDate
        let phase    = fmod(t, cycleDuration) / cycleDuration   // 0.0 … 1.0
        // scanPos is a float: 0 = above top row, rowCount = below bottom row.
        let rowCount = Double(bannerRows.count)
        let scanPos  = phase * (rowCount + 2) - 1               // -1 … rowCount+1

        // Idle: slow colour-wave cycling once every ~14 s
        let rainbowOffset = Int(t / 2.3)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<bannerRows.count, id: \.self) { i in
                Text(bannerRows[i])
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(rowColor(row: i, scanPos: scanPos,
                                              rainbowOffset: rainbowOffset))
                    .fixedSize()
            }
        }
        .padding(.bottom, 2)
    }

    private func rowColor(row: Int, scanPos: Double, rainbowOffset: Int) -> Color {
        if !isActive {
            // Idle: slow rainbow gradient, no animation flicker
            return Color.rainbow[(row + rainbowOffset) % Color.rainbow.count]
        }

        // Active: bright white scanline sweeps downward continuously.
        // dist is how far this row is from the scanline centre (in rows).
        let dist = Double(row) - scanPos
        let absDist = abs(dist)

        switch absDist {
        case ..<0.55: return Color(white: 1.0)
        case ..<1.1:  return Color(white: 0.88)
        case ..<1.8:  return Color(red: 1.0, green: 0.42, blue: 0.42)
        default:      return Color(red: 0.58, green: 0.0, blue: 0.0)
        }
    }

    // MARK: - Tagline box

    private var taglineBox: some View {
        let now     = nowFull()
        let right   = "[ \(taglineVersion) ]  \(now)"
        // Minimal gap — just 2 spaces between the tagline and version/time
        let midLine = "  ║ \(taglineText)  \(right) ║"
        let W       = midLine.count - 4   // border width matches actual content

        return VStack(alignment: .leading, spacing: 0) {
            Text("  ╔\(String(repeating: "═", count: W))╗")
            Text(midLine)
            Text("  ╚\(String(repeating: "═", count: W))╝")
        }
        .font(.mono)
        .foregroundColor(.termDim)
        .fixedSize()
    }

    // MARK: - Watch section

    @ViewBuilder
    private var watchSection: some View {
        if watchFolders.isEmpty {
            Text("  ·· drop a folder here or click Add Folder ··")
                .font(.mono)
                .foregroundColor(.termDim)
                .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("  ▶ WATCHING:")
                    .font(.monoHdr)
                    .foregroundColor(.termGreen)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(watchFolders) { folder in
                    folderLine(folder)
                }
            }
            .padding(.top, 4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // A folder line. The path sits left; status + existing-files sit right,
    // separated by a flexible Spacer so the gap adapts to the window width
    // and the right side never gets pushed off-screen.
    private func folderLine(_ folder: WatchedFolder) -> some View {
        let active = folder.tracker.activeEntries.count
        let baseColor: Color = folder.isWatching ? .termGreen : .termDim

        let statusWord = !folder.isWatching ? "stopped"
                       : active > 0         ? "\(active) writing"
                       :                      "idle"
        let existing = folder.existingCount > 0
            ? "\(folder.existingCount) existing file\(folder.existingCount == 1 ? "" : "s")"
            : ""
        var leftParts = [statusWord]
        if !existing.isEmpty { leftParts.append(existing) }
        let statusText = leftParts.joined(separator: "  ·  ")
        let statusColor: Color = folder.isWatching
            ? (active > 0 ? .termOrange : Color.termGreen.opacity(0.7))
            : .termDim

        return HStack(spacing: 8) {
            Text("      \(folder.path)")
                .foregroundColor(baseColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)

            Spacer(minLength: 16)

            Text(statusText)
                .foregroundColor(statusColor)
                .lineLimit(1)
                .fixedSize()

            // Free disk space — color-coded by absolute remaining space
            if let free = folder.freeSpace {
                Text("·").foregroundColor(.termDim)
                Text("\(fmtSize(free)) free")
                    .foregroundColor(diskSpaceColor(free))
                    .lineLimit(1)
                    .fixedSize()
                    .blink(diskSpaceIsCritical(free))
            }
        }
        .font(.mono)
        // Cap the row width so the Spacer has a sensible bound; the row
        // shrinks with the window but won't stretch absurdly wide.
        .frame(maxWidth: 700, alignment: .leading)
    }
}
