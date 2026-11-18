import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    // House-theme neutrals. Accent roles live in Palette.
    static let appBackground = Color(hex: 0x1B1B1B)
    static let surfaceLowered = Color(hex: 0x222222)
    static let controlAlt = Color(hex: 0x2A2A2A)
    static let cardSurface = Color(hex: 0x2C2C2C)
    static let cardShadow = Color(hex: 0x000000).opacity(0.35)
    static let pressed = Color(hex: 0x383838)
    static let hover = Color(hex: 0x404040)
    static let borderSubtle = Color(hex: 0x3F3F3F)
    static let borderStrong = Color(hex: 0x5E5E5E)
    static let textPrimary = Color(hex: 0xFFFFFF)
    static let textCardBack = Color(hex: 0xEAEAEA)
    static let textSecondary = Color(hex: 0xD0D0D0)
    static let textTertiary = Color(hex: 0xCCCCCC)
    static let textMeta = Color(hex: 0xB3B3B3)
    static let textMuted = Color(hex: 0x888888)
}

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
