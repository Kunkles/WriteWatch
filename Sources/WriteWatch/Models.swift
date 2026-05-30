import Foundation
import SwiftUI

// MARK: - FileStatus

enum FileStatus: Equatable {
    case writing, done
}

// MARK: - ValidationState

enum ValidationState: Equatable {
    case none
    case checking
    case valid(String)
    case corrupt(String)
    case stillOpen
    case noProbe

    var symbol: String {
        switch self {
        case .none:      return "—"
        case .checking:  return "checking…"
        case .valid:     return "✓ valid"
        case .corrupt:   return "✗ corrupt"
        case .stillOpen: return "⚠ still open"
        case .noProbe:   return "? unavailable"
        }
    }

    var detail: String {
        switch self {
        case .valid(let d):   return d
        case .corrupt(let d): return d
        case .stillOpen:      return "process still holds the file open"
        default:              return ""
        }
    }

    var color: Color {
        switch self {
        case .valid:     return .termGreen
        case .corrupt:   return .termRed
        case .stillOpen: return .termYellow
        default:         return .termDim
        }
    }
}

// MARK: - FileEntry

struct FileEntry: Identifiable, Equatable {
    var id: String { path }

    let   path:          String
    let   name:          String
    var   size:          Int64
    var   lastSize:      Int64
    var   lastCheck:     Date
    var   rate:          Double      // bytes / second
    var   peakRate:      Double
    var   status:        FileStatus
    let   started:       Date
    var   finished:      Date?
    var   duration:      TimeInterval?     // media playback length (from AVFoundation probe)
    var   events:        Int
    var   validation:    ValidationState
    let   isPreExisting: Bool
    /// True when the file was already being written to when the folder was added.
    /// The size shown reflects only bytes written after we started watching.
    var   isMidJoin:     Bool
    /// True if the video track has a variable frame rate (flagged during probe).
    var   isVFR:         Bool = false
    /// Nominal (average) frame rate of the video track, from the probe. nil if unknown.
    var   frameRate:     Double? = nil
    /// Wall-clock time this entry was first seen. Guards the stale grace period.
    var   discoveredAt:  Date
    /// Size observed at the moment we first saw the file (mid-join baseline).
    /// Added to the final reported size so totals are accurate.
    var   baselineSize:  Int64

    // MARK: - Duration accuracy

    /// How well the wall-clock recording time matches the media playback length.
    enum DurationMatch {
        case imported     // pre-existing file, not recorded live → purple
        case exact        // within ~1s → bright green
        case close        // within ~5s → yellow
        case off          // way off → red
        case unknown      // can't compare (mid-join, no duration yet, still writing)
    }

    /// Compares elapsed recording time to media duration.
    var durationMatch: DurationMatch {
        // Imported files weren't recorded live — no meaningful comparison.
        if isPreExisting { return .imported }
        // Mid-join files joined partway, so elapsed is incomplete.
        if isMidJoin { return .unknown }
        // Need both a finish time and a probed media duration.
        guard status == .done,
              let finished = finished,
              let media = duration, media > 0
        else { return .unknown }

        // `finished` is recorded ~staleSeconds after the true end of the write,
        // so subtract that tail to recover the real observed elapsed time.
        let staleTail = AppSettings.shared.staleSeconds
        let elapsed   = finished.timeIntervalSince(started) - staleTail
        let diff      = abs(elapsed - media)

        if diff <= 1.5 { return .exact }   // green — within ~1.5s
        if diff <= 5.0 { return .close }   // yellow — slightly off
        return .off                        // red — significantly off
    }

    static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.path       == rhs.path       &&
        lhs.size       == rhs.size       &&
        lhs.status     == rhs.status     &&
        lhs.isMidJoin  == rhs.isMidJoin  &&
        lhs.isVFR      == rhs.isVFR      &&
        lhs.frameRate  == rhs.frameRate  &&
        lhs.duration   == rhs.duration   &&
        lhs.validation == rhs.validation
    }
}
