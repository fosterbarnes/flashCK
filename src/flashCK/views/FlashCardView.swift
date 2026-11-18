import SwiftUI
import flashCKCore

/// The study card: an index-card shape centered in the panel. The back is tinted (`palette.cardBack`)
/// with an accent bar on top. Tap flips with a 3D turn (instant when Reduce Motion is on). The star
/// button sits in the top right corner.
struct FlashCardView: View {
    let card: Card
    let showBack: Bool
    let flip: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette

    var body: some View {
        let angle: Double = showBack ? 180 : 0
        ZStack {
            face(card.front, isBack: false).modifier(FlipTurn(angle: angle, isBack: false))
            face(card.back, isBack: true).modifier(FlipTurn(angle: angle, isBack: true))
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: Metrics.flipDuration), value: showBack)
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .onTapGesture(perform: flip)
        .help("Click or press Space to flip")
        .aspectRatio(Metrics.cardAspect, contentMode: .fit)
        // Outside the flip: the star stays put on both faces, and clicking it does not flip the card.
        .overlay(
            StarButton(card: card, size: 16, name: "card")
                .padding(.top, Metrics.cardStripeHeight + 4)
                .padding(.trailing, 8),
            alignment: .topTrailing
        )
        .frame(maxWidth: Metrics.cardMaxWidth, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    private func face(_ text: String, isBack: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            Text(text.isEmpty ? "Empty" : text)
                .font(.system(size: 26))
                .foregroundColor(text.isEmpty ? .textMuted : isBack ? .textCardBack : .textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(isBack ? "Back" : "Front")
                .font(.system(size: 12))
                .foregroundColor(.textMuted)
                .padding(.top, isBack ? 10 + Metrics.cardStripeHeight : 10)
                .padding(.leading, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .fill(isBack ? palette.cardBack : .cardSurface)
                .shadow(color: .cardShadow, radius: 12, x: 0, y: 6)
        )
        // The back is tinted and carries an accent bar on its top edge, so the side reads at a glance.
        .overlay(isBack ? stripe : nil)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(Color.borderSubtle)
        )
    }

    /// Accent bar along the top edge, clipped to the card's rounded corners.
    private var stripe: some View {
        Rectangle()
            .fill(palette.accent)
            .frame(height: Metrics.cardStripeHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
            .allowsHitTesting(false)
    }
}

/// Turns one face about the card's vertical axis. The front shows below 90 degrees and the back
/// above, so the faces swap exactly when the card is edge-on. The back is pre-mirrored so it reads
/// correctly once turned.
private struct FlipTurn: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool
    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: isBack ? -1 : 1, y: 1)
            .opacity((angle >= 90) == isBack ? 1 : 0)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

/// Shuffle and Back first for the Study tab: icon toggles, lit when on.
struct SideToggles: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            toggle("shuffle", "Shuffle", isOn: model.prefs.shuffle,
                   help: "Show cards in random order") { model.toggleShuffle() }
            toggle("arrow.left.arrow.right", "Back first", isOn: model.prefs.backFirst,
                   help: "Show the back side first") { model.toggleBackFirst() }
        }
    }

    private func toggle(_ symbol: String, _ name: String, isOn: Bool, help: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(NeutralButtonStyle(isOn: isOn, minWidth: 36))
            .help("\(name): \(isOn ? "on" : "off"). \(help)")
            .accessibilityLabel(name)
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
