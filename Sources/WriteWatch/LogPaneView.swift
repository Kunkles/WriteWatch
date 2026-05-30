import SwiftUI

struct LogPaneView: View {
    @ObservedObject var logger: FolderLogger
    @State private var autoscroll = true

    private static let tagColors: [String: Color] = [
        "VALID":         .green,
        "CORRUPT":       .red,
        "OPEN":          .yellow,
        "STARTED":       .cyan,
        "COMPLETED":     .blue,
        "SNAPSHOT":      .secondary,
        "SCAN":          .secondary,
        "SESSION START": .purple,
        "SESSION END":   .purple,
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(logger.entries) { entry in
                        logRow(entry).id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: logger.entries.count) { _, _ in
                if autoscroll, let last = logger.entries.last {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Toggle("Autoscroll", isOn: $autoscroll)
                .toggleStyle(.checkbox)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.timeString)
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)
            Text(entry.tag)
                .fontWeight(.medium)
                .foregroundStyle(Self.tagColors[entry.tag] ?? .primary)
                .frame(width: 90, alignment: .leading)
            Text(entry.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)
            if !entry.detail.isEmpty {
                Text("·").foregroundStyle(.tertiary)
                Text(entry.detail).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .font(.system(size: 11, design: .monospaced))
    }
}
