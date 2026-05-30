import Foundation

// MARK: - LogLevel

enum LogLevel: String {
    case info    = "INFO"
    case warn    = "WARN"
    case error   = "ERROR"
    case debug   = "DEBUG"
}

// MARK: - LogEntry

struct LogEntry: Identifiable {
    let id      = UUID()
    let date    = Date()
    let level:  LogLevel
    let tag:    String    // e.g. "STARTED", "VALID", "CORRUPT", "SNAPSHOT"
    let name:   String    // filename or folder name
    let detail: String    // additional info after the | separator

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var timeString: String { Self.timeFmt.string(from: date) }

    /// Full formatted log line matching the Python format:
    /// "yyyy-MM-dd HH:mm:ss  TAG       name  |  detail"
    var fullLine: String {
        let ts = ISO8601DateFormatter().string(from: date)
            .replacingOccurrences(of: "T", with: " ")
            .replacingOccurrences(of: "Z", with: "")
        let tagPad = tag.padding(toLength: 9, withPad: " ", startingAt: 0)
        return "\(ts)  \(tagPad) \(name)  |  \(detail)"
    }
}

// MARK: - Folder-scoped logger

@MainActor
final class FolderLogger: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []
    private var fileHandle: FileHandle?
    private(set) var logFileURL: URL?

    private static let fileFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    func start(label: String) {
        let slug = label.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        let suffix = slug.isEmpty ? "" : "_\(slug)"
        let ts     = Self.fileFmt.string(from: Date())
        let name   = "video_monitor_\(ts)\(suffix).log"
        let url    = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(name)
        logFileURL = url
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
    }

    func stop() {
        fileHandle?.closeFile()
        fileHandle = nil
    }

    func log(level: LogLevel = .info, tag: String, name: String, detail: String) {
        let entry = LogEntry(level: level, tag: tag, name: name, detail: detail)
        entries.append(entry)
        if let data = (entry.fullLine + "\n").data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    func clear() { entries.removeAll() }
}
