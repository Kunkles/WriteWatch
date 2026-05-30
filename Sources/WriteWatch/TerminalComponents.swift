import SwiftUI

// MARK: - RetroBox
// Double-line ASCII box. `width` is the exact pixel width of the content
// area (sum of column frames). The VStack is pinned to that width with
// frame(width:) so the box never expands or shrinks regardless of the
// surrounding layout container.

struct RetroBox<Content: View>: View {
    let title:    String
    let subtitle: String
    let color:    Color
    let width:    CGFloat      // exact content width in points
    let content:  () -> Content

    private let charW: CGFloat = 7.23

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(topBorder)
                .font(.mono)
                .foregroundColor(color)
                .fixedSize()           // text never wraps

            content()
                .padding(.leading, 2)
                .padding(.vertical, 2)

            Text(bottomBorder)
                .font(.mono)
                .foregroundColor(color.opacity(0.7))
                .fixedSize()
        }
        // Pin the box to exactly `width` — prevents both expansion and collapse
        .frame(width: width, alignment: .leading)
    }

    private var n: Int { max(8, Int(width / charW)) }

    private var topBorder: String {
        let t = " \(title) "
        let d = max(0, n - t.count - 4)
        return "╔══\(t)\(String(repeating: "═", count: d))╗"
    }

    private var bottomBorder: String {
        let s = subtitle.isEmpty ? "" : " \(subtitle) "
        let d = max(0, n - s.count - 4)
        return "╚\(String(repeating: "═", count: d))\(s)══╝"
    }
}

// MARK: - SectionHeader  ▓▒░ LABEL ░▒▓

struct SectionHeader: View {
    let label:    String
    let trailing: String

    var body: some View {
        HStack(spacing: 0) {
            Text("▓▒░ ").foregroundColor(.termCyanDim)
            Text(label).foregroundColor(.termCyan).fontWeight(.bold)
            Text("  ░▒▓").foregroundColor(.termCyanDim)
            Spacer(minLength: 0)
            if !trailing.isEmpty {
                Text(trailing).foregroundColor(.termCyanDim)
                Text("  ▓▒░").foregroundColor(.termCyanDim)
            }
        }
        .font(.mono)
    }
}

// MARK: - Drag-resize grip  ┊

struct ResizeHandle: View {
    var body: some View {
        Text("┊")
            .font(.mono)
            .foregroundColor(Color.termDim.opacity(0.45))
            .contentShape(Rectangle().size(width: 14, height: 9999))
            .help("Drag to resize column")
    }
}

// MARK: - Spinner (fixed-width slot, zero layout shift)

private let spinnerFrames: [Character] = Array("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")

func spinnerChar(tick: Int) -> String {
    String(spinnerFrames[tick % spinnerFrames.count])
}

// Monospaced character width at 12 pt SF Mono
let charW: CGFloat = 7.23
