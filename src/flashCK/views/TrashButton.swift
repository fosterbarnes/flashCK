import SwiftUI

/// Trash icon that turns the wrong color on hover: sidebar header and rows, card rows.
struct TrashButton: View {
    let help: String
    let label: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    /// `label` is what VoiceOver reads; it defaults to the tooltip.
    init(help: String, label: String? = nil, action: @escaping () -> Void) {
        self.help = help
        self.label = label ?? help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(GhostButtonStyle(hoverText: palette.wrong))
        .help(help)
        .accessibilityLabel(label)
    }
}
