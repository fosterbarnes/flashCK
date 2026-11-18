import SwiftUI
import flashCKCore

/// Cmd+, window. Theme only.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private static let themes = [TabItem(id: ThemeID.mint, title: "Mint"), TabItem(id: ThemeID.purple, title: "Purple")]

    var body: some View {
        HStack(spacing: 12) {
            Text("Theme").font(.system(size: 13, weight: .semibold))
            TabStrip(items: Self.themes, selection: model.prefs.theme) { model.setTheme($0) }
                .help("Accent colors for every window")
        }
        .panel()
        .padding(Metrics.pageMargin)
        .frame(width: 380)
        .background(Color.appBackground)
        .foregroundColor(.textPrimary)
        .background(WindowChrome())
    }
}
