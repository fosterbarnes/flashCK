import SwiftUI

/// Primary action: rounded corners, accent fill, dark or white text per palette.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @Environment(\.palette) private var palette
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        var body: some View {
            let fill = hovering && !configuration.isPressed && isEnabled ? palette.accentHover : palette.accent
            let shape = RoundedRectangle(cornerRadius: Metrics.buttonRadius)
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.onAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: Metrics.controlMinHeight)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(isFocused ? palette.focus : fill, lineWidth: isFocused ? 2 : 1))
                .opacity(isEnabled ? 1 : 0.55)
                .contentShape(shape)
                .onHover { hovering = $0 }
        }
    }
}

/// Secondary action. `isOn` draws the toggle-on state (accentStrong fill, accentBorder border).
struct NeutralButtonStyle: ButtonStyle {
    var isOn = false
    var minWidth = Metrics.neutralButtonWidth
    var radius = Metrics.buttonRadius

    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration, isOn: isOn, minWidth: minWidth, radius: radius)
    }

    private struct Styled: View {
        let configuration: Configuration
        let isOn: Bool
        let minWidth: CGFloat
        let radius: CGFloat
        @Environment(\.palette) private var palette
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius)
            configuration.label
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minWidth: minWidth, minHeight: Metrics.neutralButtonHeight)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(border, lineWidth: isFocused ? 2 : 1))
                .opacity(isEnabled ? 1 : 0.55)
                .contentShape(shape)
                .onHover { hovering = $0 }
        }

        private var fill: Color {
            if configuration.isPressed { return .pressed }
            if hovering && isEnabled { return .hover }
            return isOn ? palette.accentStrong : .controlAlt
        }

        private var border: Color {
            if isFocused { return palette.focus }
            return isOn ? palette.accentBorder : .borderStrong
        }
    }
}

/// Borderless icon or text button that only shows a hover fill (sidebar header, card row icons, Add card, About folder buttons).
struct GhostButtonStyle: ButtonStyle {
    var hoverText: Color?

    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration, hoverText: hoverText)
    }

    private struct Styled: View {
        let configuration: Configuration
        let hoverText: Color?
        @Environment(\.palette) private var palette
        @Environment(\.isFocused) private var isFocused
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundColor(hovering ? hoverText ?? .textPrimary : .textMuted)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.smallRadius)
                        .fill(hoverText == nil && hovering ? (configuration.isPressed ? Color.pressed : .hover) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.smallRadius)
                        .strokeBorder(isFocused ? palette.focus : .clear, lineWidth: 2)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

extension View {
    /// Content panel: lowered surface, subtle border, 4pt radius, 16pt padding.
    func panel(padding: CGFloat = Metrics.panelPadding) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: Metrics.panelRadius).fill(Color.surfaceLowered))
            .overlay(RoundedRectangle(cornerRadius: Metrics.panelRadius).strokeBorder(Color.borderSubtle))
    }
}
