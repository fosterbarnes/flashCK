import SwiftUI

/// Small panel under the sidebar with the create buttons. Each opens its name entry in the main panel;
/// the button for the open entry shows as on.
struct ActionsPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let isLesson: Bool = {
            if case .lesson = model.creating { return true }
            return false
        }()
        let isCard: Bool = {
            if case .card = model.creating { return true }
            return false
        }()
        VStack(spacing: 6) {
            button("New Subject", isOn: model.creating == .subject,
                   help: "Name a new subject in the main panel (Cmd+Option+N)") { model.beginNewSubject() }
            button("New Lesson", isOn: isLesson,
                   help: "Add a lesson to a subject (Cmd+Shift+N)") { model.beginNewLesson() }
                .disabled(model.library.subjects.isEmpty)
            button("New Card", isOn: isCard,
                   help: "Add a card to a lesson (Cmd+N adds to the selected lesson)") { model.beginNewCard() }
                .disabled(model.library.lessons.isEmpty)
        }
        .panel(padding: 8)
    }

    private func button(_ title: String, isOn: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // Title centered on the button; the icon sits at the right edge so it lines up down the panel.
            Text(title)
                .font(.mono(13.5, weight: .semibold)) // same as the tab titles
                .frame(maxWidth: .infinity)
                .overlay(
                    LucideIcon(name: .plus, size: 14, strokeWidth: 3),
                    alignment: .trailing
                )
        }
        // Wide buttons stacked in a small panel: a smaller radius than other buttons, matching the panel's.
        .buttonStyle(NeutralButtonStyle(isOn: isOn, radius: Metrics.panelRadius))
        .help(help)
    }
}
