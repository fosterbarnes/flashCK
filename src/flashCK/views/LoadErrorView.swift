import AppKit
import SwiftUI

/// Shown instead of the library when library.json could not be loaded. Nothing is saved in this state.
struct LoadErrorView: View {
    let message: String
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Could not open the library")
                .font(.system(size: 20, weight: .semibold))
            Text(message)
                .foregroundColor(palette.wrong)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Text("flashCK will not save anything until this file loads. Fix or move it, then reopen flashCK.")
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.paths.libraryURL.path)
                .font(.mono(12))
                .foregroundColor(.textMeta)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Button("Open data folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.paths.libraryURL])
                }
                .buttonStyle(AccentButtonStyle())
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(NeutralButtonStyle())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .panel()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
