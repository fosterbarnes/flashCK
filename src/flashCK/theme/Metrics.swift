import CoreGraphics

/// House-theme spacing and radii, plus flashCK layout sizes.
enum Metrics {
    static let pageMargin: CGFloat = 12
    static let panelPadding: CGFloat = 16
    static let smallRadius: CGFloat = 3
    static let panelRadius: CGFloat = 4
    /// Accent and neutral buttons, and the All | star switch track.
    static let buttonRadius: CGFloat = 6
    static let segmentHeight: CGFloat = 32
    static let neutralButtonWidth: CGFloat = 92
    static let neutralButtonHeight: CGFloat = 30
    static let controlMinHeight: CGFloat = 34
    static let sidebarWidth: CGFloat = 230
    static let fadeDuration = 0.18
    static let slideDuration = 0.3
    static let cardRadius: CGFloat = 10
    static let cardAspect: CGFloat = 5.0 / 3.0
    static let cardMaxWidth: CGFloat = 620
    /// Accent bar across the top of the study card's back face.
    static let cardStripeHeight: CGFloat = 7
    static let flipDuration = 0.45
    static let cardSlideDuration = 0.25
}
