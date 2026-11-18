import SwiftUI

/// The Study tab. Browse: card, Flip, previous / position / next, Shuffle and Back first.
struct StudyCardsTab: View {
    @EnvironmentObject private var model: AppModel
    /// With Keyboard navigation on, Space presses the focused control, so Flip starts focused.
    @FocusState private var flipFocused: Bool

    var body: some View {
        Group {
            if let session = model.cardsSession, let id = session.current, let card = model.library.card(id: id) {
                VStack(spacing: 12) {
                    // New identity per card, so moving on never plays a flip that shows the next back,
                    // and Previous / Next slide the old card out as the new one slides in.
                    GeometryReader { geo in
                        FlashCardView(card: card, showBack: session.flipped != model.prefs.backFirst) { model.flip() }
                            .id(card.id)
                            .transition(.cardSlide(card.id, distance: geo.size.width + Metrics.panelPadding,
                                                   slides: model.cardSlides))
                    }
                    // Sliding cards vanish at the panel's edges: the padding widens the clip to the panel.
                    .padding(Metrics.panelPadding)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.panelRadius))
                    .padding(-Metrics.panelPadding)
                    // Flip spans exactly the navigation row below it (fixedSize sizes the column to that
                    // row); the column is centered on the panel and the toggles stay pinned right.
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 12) {
                            Button { model.flip() } label: {
                                Text("Flip").font(.mono(13.5, weight: .semibold)).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(NeutralButtonStyle(minWidth: 0))
                            .help("Flip the card (Space, or click the card)")
                            .focused($flipFocused)
                            HStack(spacing: 8) {
                                Button { model.previousCard() } label: { Image(systemName: "chevron.left") }
                                    .buttonStyle(NeutralButtonStyle(minWidth: 36))
                                    .help("Previous card (Left arrow)")
                                    .disabled(!session.canStep)
                                    .accessibilityLabel("Previous card")
                                Text("\(session.index + 1) / \(session.count)")
                                    .font(.mono(13))
                                    .foregroundColor(.textSecondary)
                                Button { model.nextCard() } label: { Image(systemName: "chevron.right") }
                                    .buttonStyle(NeutralButtonStyle(minWidth: 36))
                                    .help("Next card (Right arrow)")
                                    .disabled(!session.canStep)
                                    .accessibilityLabel("Next card")
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        HStack {
                            Spacer()
                            SideToggles()
                        }
                    }
                }
            } else {
                NoCardsView()
            }
        }
        .studyKeys(model)
        .onAppear {
            guard NSApp.isFullKeyboardAccessEnabled else { return }
            Task { @MainActor in flipFocused = true }
        }
    }
}

/// Directions of the study card slide. A leaving card keeps the transition it last rendered with,
/// which can predate the move, so its transition reads this while it runs instead.
@MainActor
final class CardSlides {
    /// Direction of the latest move: forward cards arrive from the right.
    private(set) var forward = true
    /// Whether each card last left going forward (out to the left), keyed by card ID.
    private var exits: [UUID: Bool] = [:]

    func record(leaving id: UUID, forward: Bool) {
        self.forward = forward
        exits[id] = forward
    }

    /// Side a leaving card exits to: -1 left, 1 right.
    func exitSide(_ id: UUID) -> CGFloat { exits[id] == false ? 1 : -1 }
}

extension AnyTransition {
    /// Study card Previous / Next: in from one side, out the other, `distance` points.
    @MainActor
    static func cardSlide(_ id: UUID, distance: CGFloat, slides: CardSlides) -> AnyTransition {
        let enter: CGFloat = slides.forward ? 1 : -1
        return .asymmetric(
            insertion: .modifier(active: CardSlide(progress: 1, distance: distance) { enter },
                                 identity: CardSlide(progress: 0, distance: distance) { enter }),
            removal: .modifier(active: CardSlide(progress: 1, distance: distance) { slides.exitSide(id) },
                               identity: CardSlide(progress: 0, distance: distance) { slides.exitSide(id) })
        )
    }
}

/// Offsets the card sideways: `progress` 0 is in place, 1 is `distance` toward `side` (-1 left, 1 right).
private struct CardSlide: ViewModifier, Animatable {
    var progress: Double
    let distance: CGFloat
    let side: @MainActor () -> CGFloat
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: side() * distance * progress)
    }
}
