import Foundation

func fmtSize(_ bytes: Int64) -> String {
    var b = Double(bytes)
    for unit in ["B", "KB", "MB", "GB", "TB"] {
        if b < 1024 { return String(format: "%.1f \(unit)", b) }
        b /= 1024
    }
    return String(format: "%.1f PB", b)
}

func fmtRate(_ bps: Double) -> String {
    guard bps > 0 else { return "—" }
    var r = bps
    for unit in ["B/s", "KB/s", "MB/s", "GB/s"] {
        if r < 1024 { return String(format: "%.1f \(unit)", r) }
        r /= 1024
    }
    return String(format: "%.2f TB/s", r)
}

func fmtDur(_ secs: TimeInterval) -> String {
    let s   = Int(max(0, secs))
    let sec = s % 60
    let min = (s / 60) % 60
    let hr  = s / 3600
    if hr  > 0 { return "\(hr)h \(String(format: "%02d", min))m" }
    if min > 0 { return "\(min)m \(String(format: "%02d", sec))s" }
    return "\(sec)s"
}

private let _timeFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
}()

private let _fullFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd  HH:mm:ss"; return f
}()

func nowTime() -> String { _timeFmt.string(from: Date()) }
func nowFull() -> String { _fullFmt.string(from: Date()) }

// MARK: - Disk space color thresholds

import SwiftUI

/// Color for remaining free disk space, by absolute bytes:
///   > 1 TB   → green
///   > 500 GB → yellow
///   > 200 GB → orange
///   > 100 GB → red-ish (still readable)
///   ≤ 100 GB → red
func diskSpaceColor(_ freeBytes: Int64) -> Color {
    let gb = Double(freeBytes) / 1_000_000_000.0   // decimal GB (matches drive labels)
    switch gb {
    case 1000...:      return .green                          // ≥ 1 TB
    case 500..<1000:   return .yellow                         // 500 GB – 1 TB
    case 200..<500:    return .orange                         // 200 – 500 GB
    case 100..<200:    return .red                            // 100 – 200 GB
    default:           return Color(red: 1, green: 0.15, blue: 0.15)  // < 100 GB — critical
    }
}

/// True when free space is low enough to blink a warning (< 200 GB — both red
/// tiers). The sub-100 GB tier blinks in a brighter, more urgent red.
func diskSpaceIsCritical(_ freeBytes: Int64) -> Bool {
    Double(freeBytes) / 1_000_000_000.0 < 200
}

// MARK: - Frame rate

/// Formats a frame rate for display, snapping to the common broadcast rates
/// (23.976, 29.97, 59.94) that often read as 23.98/29.97 from the container.
func fmtFrameRate(_ fps: Double) -> String {
    let common: [(Double, String)] = [
        (23.976, "23.976"), (24.0, "24"), (25.0, "25"),
        (29.97,  "29.97"),  (30.0, "30"), (50.0, "50"),
        (59.94,  "59.94"),  (60.0, "60"), (120.0, "120")
    ]
    for (rate, label) in common where abs(fps - rate) < 0.02 {
        return "\(label) fps"
    }
    // Non-standard rate — show one decimal place
    return String(format: "%.2f fps", fps)
}
