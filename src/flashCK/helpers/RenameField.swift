import SwiftUI

/// Inline rename for sidebar rows and the header title. Return, losing focus, or the field going away
/// (another row picked, a new item started) commits; Esc cancels.
struct RenameField: View {
    let font: Font
    let commit: (String) -> Void
    let cancel: () -> Void
    @State private var text: String
    @State private var finished = false
    @FocusState private var focused: Bool
    @Environment(\.palette) private var palette

    init(initial: String, font: Font = .system(size: 13), commit: @escaping (String) -> Void,
         cancel: @escaping () -> Void) {
        _text = State(initialValue: initial)
        self.font = font
        self.commit = commit
        self.cancel = cancel
    }

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Metrics.smallRadius).fill(Color.appBackground))
            .overlay(RoundedRectangle(cornerRadius: Metrics.smallRadius).strokeBorder(palette.focus, lineWidth: 2))
            .focused($focused)
            .onSubmit { finish(commit: true) }
            .onExitCommand { finish(commit: false) }
            .onChange(of: focused) { isFocused in
                if !isFocused { finish(commit: true) }
            }
            .onAppear { Task { @MainActor in focused = true } }
            .onDisappear { finish(commit: true) }
    }

    private func finish(commit shouldCommit: Bool) {
        guard !finished else { return }
        finished = true
        if shouldCommit { commit(text) } else { cancel() }
    }
}
