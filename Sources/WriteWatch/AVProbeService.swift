import AVFoundation
import CoreMedia

/// Replaces FFProbeService using native AVFoundation — no ffprobe subprocess needed.
/// Matches FFProbeService.Outcome exactly so FileTracker needs no interface changes.
struct AVProbeService {

    struct Outcome {
        enum State { case valid, corrupt, notAvailable }
        let state: State
        let detail: String
        let durationSeconds: Double?
        var isVFR: Bool = false
        var frameRate: Double? = nil
    }

    /// AVFoundation is always available, so this is always true.
    static let isAvailable = true

    func probe(path: String) async -> Outcome {
        let url   = URL(fileURLWithPath: path)
        // Disable precise timing — we only need duration + tracks, not frame-accurate seeks.
        let asset = AVURLAsset(url: url,
                               options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])

        do {
            // isReadable catches truncated / unrecognised containers up front.
            let readable = try await asset.load(.isReadable)
            guard readable else {
                return Outcome(state: .corrupt, detail: "unreadable container", durationSeconds: nil)
            }

            let cmDuration = try await asset.load(.duration)
            let duration   = CMTimeGetSeconds(cmDuration)

            let tracks = try await asset.load(.tracks)
            guard !tracks.isEmpty else {
                return Outcome(state: .corrupt, detail: "no tracks", durationSeconds: nil)
            }

            var videoCodecs: [String] = []
            var audioCodecs: [String] = []

            // load video and audio tracks separately — avoids the
            // .mediaType async property which is unavailable in some SDK versions.
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            var isVFR = false
            var frameRate: Double? = nil
            for track in videoTracks {
                let fmtDescs = try await track.load(.formatDescriptions)
                let codec    = fmtDescs.first.map { Self.codecName(for: $0) } ?? "unknown"
                videoCodecs.append(codec)

                // Frame rate from the EXACT rational time. minFrameDuration is a
                // CMTime (e.g. 1001/30000 for 29.97, 1/30 for true 30). The
                // nominalFrameRate Float is rounded and unreliable — it reports
                // true 30 fps as 29.97. Prefer the rational; fall back to nominal.
                let minDur = try? await track.load(.minFrameDuration)
                if let minDur, minDur.isValid, minDur.value > 0 {
                    let exactFPS = Double(minDur.timescale) / Double(minDur.value)
                    frameRate = exactFPS
                    if let nominal = try? await track.load(.nominalFrameRate), nominal > 0 {
                        if exactFPS > Double(nominal) * 1.05 { isVFR = true }
                    }
                } else if let nominal = try? await track.load(.nominalFrameRate), nominal > 0 {
                    frameRate = Double(nominal)
                }
            }
            for track in audioTracks {
                let fmtDescs = try await track.load(.formatDescriptions)
                let codec    = fmtDescs.first.map { Self.codecName(for: $0) } ?? "unknown"
                audioCodecs.append(codec)
            }

            // Build a detail string in the same style FFProbeService used.
            var parts: [String] = []
            if let v = videoCodecs.first { parts.append(v) }
            if !audioCodecs.isEmpty {
                var seen   = Set<String>()
                var unique = [String]()
                for c in audioCodecs where seen.insert(c).inserted { unique.append(c) }
                var audioStr = unique[0]
                if audioCodecs.count > 1 { audioStr += " x\(audioCodecs.count)" }
                parts.append(audioStr)
            }

            if isVFR { parts.append("VFR") }
            let detail = parts.isEmpty ? "no a/v streams" : parts.joined(separator: "  ")
            return Outcome(state: .valid,
                           detail: detail,
                           durationSeconds: duration.isFinite ? duration : nil,
                           isVFR: isVFR,
                           frameRate: frameRate)

        } catch {
            return Outcome(state: .corrupt,
                           detail: error.localizedDescription,
                           durationSeconds: nil)
        }
    }

    // MARK: - Codec name helpers

    private static func codecName(for desc: CMFormatDescription) -> String {
        fourCCName(CMFormatDescriptionGetMediaSubType(desc))
    }

    private static func fourCCName(_ code: FourCharCode) -> String {
        switch code {
        // ── Video ──────────────────────────────────────────────────────────
        case kCMVideoCodecType_H264:              return "h264"
        case kCMVideoCodecType_HEVC:              return "hevc"
        case kCMVideoCodecType_MPEG4Video:        return "mpeg4"
        case kCMVideoCodecType_MPEG2Video:        return "mpeg2"
        case kCMVideoCodecType_MPEG1Video:        return "mpeg1"
        case kCMVideoCodecType_JPEG:              return "mjpeg"
        case kCMVideoCodecType_AppleProRes4444:   return "prores4444"
        case kCMVideoCodecType_AppleProRes422:    return "prores422"
        case kCMVideoCodecType_AppleProRes422HQ:  return "prores422hq"
        case kCMVideoCodecType_AppleProRes422LT:  return "prores422lt"
        case kCMVideoCodecType_AppleProRes422Proxy: return "prores422proxy"
        case kCMVideoCodecType_AppleProResRAW:    return "proresraw"
        case 0x5230422B:                          return "proresraw+" // 'R0B+' kCMVideoCodecType_AppleProResRAWPlus
        // VP9 / AV1 via raw FourCC (constants require later SDK versions)
        case 0x56503930:                          return "vp9"   // 'VP90'
        case 0x61763031:                          return "av1"   // 'av01'
        // ── Audio ──────────────────────────────────────────────────────────
        case kAudioFormatMPEG4AAC:                return "aac"
        case kAudioFormatMPEGLayer3:              return "mp3"
        case kAudioFormatMPEGLayer2:              return "mp2"
        case kAudioFormatMPEGLayer1:              return "mp1"
        case kAudioFormatLinearPCM:               return "pcm"
        case kAudioFormatAC3:                     return "ac3"
        case kAudioFormatEnhancedAC3:             return "eac3"
        case kAudioFormatAppleLossless:           return "alac"
        case kAudioFormatFLAC:                    return "flac"
        case kAudioFormatOpus:                    return "opus"
        // ── Fallback: print the FourCC characters ──────────────────────────
        default:
            let bytes: [UInt8] = [
                UInt8((code >> 24) & 0xFF),
                UInt8((code >> 16) & 0xFF),
                UInt8((code >>  8) & 0xFF),
                UInt8( code        & 0xFF),
            ]
            let s = String(bytes: bytes, encoding: .ascii)?
                        .trimmingCharacters(in: .whitespaces) ?? ""
            return s.isEmpty ? String(format: "0x%08x", code) : s
        }
    }
}
