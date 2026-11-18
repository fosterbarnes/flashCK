import SwiftUI

/// Icons from Lucide (https://lucide.dev), drawn as SwiftUI shapes on Lucide's 24x24 grid, so they need
/// no bundled assets and work on macOS 12. `strokeWidth` is in grid units like Lucide's `stroke-width`
/// (default 2) and scales with `size`. The color is the current foreground color; `filled` also fills
/// the outline with it.
/// Lucide: ISC License, Copyright (c) 2026 Lucide Icons and Contributors; Feather-derived icons (plus)
/// also MIT, Copyright (c) 2013-present Cole Bemis. Full text in THIRD_PARTY_NOTICES.txt.
struct LucideIcon: View {
    enum Name {
        case plus, star
    }

    let name: Name
    var size: CGFloat = 14
    var strokeWidth: CGFloat = 2
    var filled = false

    var body: some View {
        let shape = LucideShape(name: name)
        shape
            .stroke(style: StrokeStyle(lineWidth: strokeWidth * size / 24, lineCap: .round, lineJoin: .round))
            .background(filled ? shape.fill() : nil)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Each case copies the icon's SVG paths, in 24x24 grid coordinates.
private struct LucideShape: Shape {
    let name: LucideIcon.Name

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch name {
        case .plus:
            // <path d="M5 12h14" /> <path d="M12 5v14" />
            p.move(to: CGPoint(x: 5, y: 12)); p.addLine(to: CGPoint(x: 19, y: 12))
            p.move(to: CGPoint(x: 12, y: 5)); p.addLine(to: CGPoint(x: 12, y: 19))
        case .star:
            // Feather-era star: <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77
            // 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" /> (round joins soften the points)
            p.addLines([
                CGPoint(x: 12, y: 2), CGPoint(x: 15.09, y: 8.26), CGPoint(x: 22, y: 9.27),
                CGPoint(x: 17, y: 14.14), CGPoint(x: 18.18, y: 21.02), CGPoint(x: 12, y: 17.77),
                CGPoint(x: 5.82, y: 21.02), CGPoint(x: 7, y: 14.14), CGPoint(x: 2, y: 9.27),
                CGPoint(x: 8.91, y: 8.26),
            ])
            p.closeSubpath()
        }
        let scale = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}
