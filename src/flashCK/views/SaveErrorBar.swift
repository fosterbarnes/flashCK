import SwiftUI

/// A failed write (library, preferences, or the launch backup) with Retry.
struct SaveErrorBar: View {
    let message: String
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .foregroundColor(palette.wrong)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Retry") { model.flush() }
                .buttonStyle(NeutralButtonStyle())
                .help("Try the failed save again")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Metrics.panelRadius).fill(Color.surfaceLowered))
        .overlay(RoundedRectangle(cornerRadius: Metrics.panelRadius).strokeBorder(palette.wrong))
    }
}
