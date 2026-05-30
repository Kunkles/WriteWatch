import SwiftUI

// MARK: - Colors

extension Color {
    static let termBg      = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let termGreen   = Color(red: 0.18, green: 0.88, blue: 0.18)
    static let termYellow  = Color(red: 1.00, green: 0.90, blue: 0.00)
    static let termOrange  = Color(red: 1.00, green: 0.53, blue: 0.00)
    static let termRed     = Color(red: 1.00, green: 0.22, blue: 0.22)
    static let termMagenta = Color(red: 0.85, green: 0.18, blue: 0.85)
    static let termBlue    = Color(red: 0.32, green: 0.52, blue: 1.00)
    static let termCyan    = Color(red: 0.00, green: 0.85, blue: 0.90)
    static let termCyanDim = Color(red: 0.00, green: 0.50, blue: 0.55)
    static let termDim     = Color(white: 0.32)
    static let termDimMid  = Color(white: 0.45)
    static let termWhite   = Color(white: 0.90)

    /// Vintage Apple rainbow — one entry per banner row, top-to-bottom
    static let rainbow: [Color] = [
        .termGreen, .termYellow, .termOrange, .termRed, .termMagenta, .termBlue
    ]
}

// MARK: - Fonts

extension Font {
    static let mono    = Font.system(size: 12, design: .monospaced)
    static let monoSm  = Font.system(size: 11, design: .monospaced)
    static let monoBg  = Font.system(size: 11, design: .monospaced) // banner
    static let monoHdr = Font.system(size: 12, weight: .bold, design: .monospaced)
}
