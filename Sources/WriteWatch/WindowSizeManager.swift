import AppKit
import SwiftUI

// MARK: - WindowSizeManager
// Persists per-mode window widths and resizes the window when the mode
// switches.  Classic defaults to the table's natural column width on first
// launch; after that both modes remember whatever the user last resized to.

@MainActor
final class WindowSizeManager: ObservableObject {

    // Persisted widths — 0 means "not yet set, use default"
    @AppStorage("ww.classicWindowWidth") var classicWidth: Double = 0
    @AppStorage("ww.modernWindowWidth")  var modernWidth:  Double = 0
    @AppStorage("ww.tallyWindowWidth")   var tallyWidth:   Double = 0

    // Called once on launch to set defaults if never stored
    func setDefaultsIfNeeded(classicTableWidth: CGFloat) {
        if classicWidth <= 0 { classicWidth = Double(classicTableWidth) }
        if modernWidth  <= 0 { modernWidth  = 1200 }
        if tallyWidth   <= 0 { tallyWidth   = 480 }
    }

    // Save the current window width under the given mode key
    func recordWidth(for mode: AppViewMode) {
        guard let w = NSApp.keyWindow?.frame.width, w > 100 else { return }
        switch mode {
        case .classic: classicWidth = Double(w)
        case .modern:  modernWidth  = Double(w)
        case .tally:   tallyWidth   = Double(w)
        }
    }

    // Animate the window to the stored width for the incoming mode
    func applyWidth(for mode: AppViewMode) {
        guard let window = NSApp.keyWindow else { return }
        let targetWidth: CGFloat = {
            switch mode {
            case .classic: return CGFloat(classicWidth)
            case .modern:  return CGFloat(modernWidth)
            case .tally:   return CGFloat(tallyWidth)
            }
        }()
        guard targetWidth > 100 else { return }

        var frame = window.frame
        // Anchor the right edge so the window expands/shrinks to the left
        let dx = targetWidth - frame.width
        frame.origin.x   -= dx
        frame.size.width  = targetWidth
        window.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - WindowAccessor
// NSViewRepresentable that hands us the NSWindow as soon as it's available.
// Used to hook up the resize-notification observer.

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        // Window may not be attached yet — defer to next run-loop tick
        DispatchQueue.main.async {
            if let w = v.window { self.onWindow(w) }
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { self.onWindow(w) }
        }
    }
}
