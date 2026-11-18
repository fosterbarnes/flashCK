import SwiftUI
import flashCKCore

/// Accent roles that change with the Theme setting. Neutrals are in Colors.swift.
struct Palette: Sendable {
    let accentStrong: Color  // selected tab, row, and toggle fill (white text)
    let accent: Color  // primary buttons, checked boxes
    let accentHover: Color
    let accentBorder: Color  // selected tab, row, and toggle border
    let focus: Color  // focus ring, accent text, chip text
    let onAccent: Color  // text on accent and accentHover fills
    let highlight: Color  // subject names
    let wrong: Color
    let cardBack: Color  // back face of the study card: cardSurface with ~7% accentStrong

    /// Sampled from the icon: background #57B181, frame #294B40, letters #E3E4B3.
    static let mint = Palette(
        accentStrong: Color(hex: 0x335744),
        accent: Color(hex: 0x57B181),
        accentHover: Color(hex: 0x79C79D),
        accentBorder: Color(hex: 0x54AA7C),
        focus: Color(hex: 0xA5D9BE),
        onAccent: Color(hex: 0x1B1B1B),
        highlight: Color(hex: 0xE3E4B3),
        wrong: Color(hex: 0xEF6F6C),
        cardBack: Color(hex: 0x2C2F2E)
    )

    /// House purple. Wrong is #EF6F6C because the house #F44336 is only 4.3:1 on the panel.
    static let purple = Palette(
        accentStrong: Color(hex: 0x523E6E),
        accent: Color(hex: 0x765E98),
        accentHover: Color(hex: 0x9373C0),
        accentBorder: Color(hex: 0x8363B0),
        focus: Color(hex: 0xAC98C7),
        onAccent: Color(hex: 0xFFFFFF),
        highlight: Color(hex: 0xF7E9B5),
        wrong: Color(hex: 0xEF6F6C),
        cardBack: Color(hex: 0x2F2D31)
    )

    static func of(_ theme: ThemeID) -> Palette {
        switch theme {
        case .mint: return .mint
        case .purple: return .purple
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.mint
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
