import SwiftUI
import flashCKCore

/// Stars or unstars one card: a muted outline when off, a filled highlight star when on.
struct StarButton: View {
    let card: Card
    var size: CGFloat = 12
    /// Spoken name of the card, such as "card 3".
    let name: String
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        Button { model.toggleStar(card.id) } label: {
            LucideIcon(name: .star, size: size, filled: card.starred)
                .foregroundColor(card.starred ? palette.highlight : nil)
        }
        .buttonStyle(GhostButtonStyle())
        .help(card.starred ? "Unstar card" : "Star card")
        .accessibilityLabel(card.starred ? "Unstar \(name)" : "Star \(name)")
        .accessibilityAddTraits(card.starred ? .isSelected : [])
    }
}

/// All | star switch in the header, shared by the Cards and Study tabs: every card, or only starred ones.
/// Two equal halves in a rounded track; the accent thumb sits inset inside the track and slides to the
/// chosen side (instant when Reduce Motion is on).
struct StarFilterSwitch: View {
    private static let segmentWidth: CGFloat = 38
    /// Gap between the track edge and the thumb; the thumb's radius shrinks by it so the curves stay parallel.
    private static let inset: CGFloat = 3
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let starred = model.prefs.starredOnly
        let track = RoundedRectangle(cornerRadius: Metrics.buttonRadius)
        let thumb = RoundedRectangle(cornerRadius: Metrics.buttonRadius - Self.inset)
        ZStack(alignment: .leading) {
            thumb
                .fill(palette.accentStrong)
                .overlay(thumb.strokeBorder(palette.accentBorder))
                .frame(width: Self.segmentWidth)
                .offset(x: starred ? Self.segmentWidth : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: Metrics.fadeDuration), value: starred)
            HStack(spacing: 0) {
                segment(starred: false, help: "Show all cards", label: "All cards") {
                    Text("All").font(.mono(13))
                }
                segment(starred: true, help: "Show only starred cards", label: "Starred cards") {
                    LucideIcon(name: .star, size: 12, filled: starred)
                        .foregroundColor(starred ? palette.highlight : nil)
                }
            }
        }
        .padding(Self.inset)
        .frame(height: Metrics.neutralButtonHeight)
        .background(track.fill(Color.controlAlt))
        .overlay(track.strokeBorder(Color.borderStrong))
    }

    private func segment<Label: View>(starred: Bool, help: String, label: String,
                                      @ViewBuilder content: () -> Label) -> some View {
        let isSelected = model.prefs.starredOnly == starred
        return Button { model.setStarredOnly(starred) } label: { content() }
            .buttonStyle(SegmentStyle(isSelected: isSelected, width: Self.segmentWidth))
            .help(help)
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// One half: brighter text when selected or hovered, focus ring on keyboard focus. No fill; the thumb is it.
    private struct SegmentStyle: ButtonStyle {
        let isSelected: Bool
        let width: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            Styled(configuration: configuration, isSelected: isSelected, width: width)
        }

        private struct Styled: View {
            let configuration: Configuration
            let isSelected: Bool
            let width: CGFloat
            @Environment(\.palette) private var palette
            @Environment(\.isFocused) private var isFocused
            @State private var hovering = false

            var body: some View {
                configuration.label
                    .foregroundColor(isSelected || hovering ? .textPrimary : .textTertiary)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.buttonRadius - StarFilterSwitch.inset)
                            .strokeBorder(isFocused ? palette.focus : .clear, lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering = $0 }
            }
        }
    }
}
