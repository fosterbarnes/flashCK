import SwiftUI
import flashCKCore

/// The Cards tab: every card in the selection as a scrolling list, grouped by lesson when a subject
/// is selected. Star marks a card; pencil (or double-click) edits a row in place; trash deletes (Cmd+Z
/// undoes). `starredOnly` hides unstarred cards (except the open one) and lessons left empty.
struct CardsTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let lessons = model.library.lessons(for: model.prefs.scope)
        let sections = lessons.map { LessonRows(lesson: $0, rows: rows(of: $0)) }
            .filter { !model.prefs.starredOnly || !$0.rows.isEmpty }
        if lessons.isEmpty {
            NoLessonsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sections.isEmpty {
            NoCardsView()
        } else {
            let grouped = model.prefs.scope.lessonID == nil
            VStack(spacing: 0) {
                // A bare Color.clear would take all spare height and push the list down.
                CardColumns(
                    star: Color.clear.frame(height: 1), number: Text("#"), front: Text("Front"), back: Text("Back"),
                    actions: Color.clear.frame(height: 1)
                )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .padding(.horizontal, CardRow.inset)
                    .padding(.bottom, 6)
                Rectangle().fill(Color.borderSubtle).frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sections) { section in
                                let lesson = section.lesson
                                if grouped { LessonHeader(lesson: lesson, count: section.rows.count) }
                                ForEach(section.rows) { row in
                                    CardRow(number: row.number, card: row.card).id(row.card.id)
                                }
                                if section.rows.isEmpty {
                                    Text("No cards yet")
                                        .font(.system(size: 13))
                                        .foregroundColor(.textMuted)
                                        .padding(.horizontal, CardRow.inset)
                                        .padding(.vertical, 10)
                                }
                                AddCardButton(lessonID: lesson.id)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    // Clicking empty list space finishes the open card.
                    .background(Color.clear.contentShape(Rectangle()).onTapGesture { model.finishEditing() })
                    .onReceive(model.$editing) { edit in
                        guard let id = edit?.cardID else { return }
                        // After this update, so a just-added row exists.
                        Task { @MainActor in proxy.scrollTo(id) }
                    }
                }
            }
        }
    }

    /// The lesson's cards with their numbers in the lesson. `starredOnly` keeps starred cards and the
    /// open one, so unstarring a card while editing it does not pull it out from under the cursor.
    private func rows(of lesson: Lesson) -> [CardRowItem] {
        let starredOnly = model.prefs.starredOnly
        let editingID = model.editing?.cardID
        return lesson.cards.enumerated().compactMap { index, card in
            guard !starredOnly || card.starred || card.id == editingID else { return nil }
            return CardRowItem(number: index + 1, card: card)
        }
    }
}

private struct CardRowItem: Identifiable {
    let number: Int
    let card: Card
    var id: UUID { card.id }
}

private struct LessonRows: Identifiable {
    let lesson: Lesson
    let rows: [CardRowItem]
    var id: UUID { lesson.id }
}

/// The fixed column layout shared by the header and every row (`Grid` is macOS 13+).
private struct CardColumns<Star: View, Number: View, Front: View, Back: View, Actions: View>: View {
    let star: Star
    let number: Number
    let front: Front
    let back: Back
    let actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            star.frame(width: 20)
            number.frame(width: 24, alignment: .trailing)
            front.frame(maxWidth: .infinity, alignment: .leading)
            back.frame(maxWidth: .infinity, alignment: .leading)
            actions.frame(width: 52, alignment: .trailing)
        }
    }
}

/// Lesson name and shown card count above its cards (subject selection only).
private struct LessonHeader: View {
    let lesson: Lesson
    let count: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(lesson.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.highlight)
                .lineLimit(1)
            Text("\(count)")
                .font(.mono(12))
                .foregroundColor(.textMuted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CardRow.inset)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 1), alignment: .bottom)
    }
}

private struct CardRow: View {
    static let inset: CGFloat = 8
    let number: Int
    let card: Card
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @State private var hovering = false

    var body: some View {
        let isEditing = model.editing?.cardID == card.id
        Group {
            // No tap gestures on the open row: on macOS they keep its text fields from taking focus.
            if isEditing {
                editor
            } else {
                display.contentShape(Rectangle()).onTapGesture(count: 2) { model.beginEditing(card.id) }
            }
        }
        .padding(.horizontal, CardRow.inset)
        .padding(.vertical, isEditing ? 6 : 8)
        .background(isEditing ? Color.cardSurface : hovering ? Color.controlAlt : .clear)
        .overlay(
            Rectangle()
                .strokeBorder(isEditing ? palette.accentBorder : .clear)
        )
        .overlay(Rectangle().fill(Color.borderSubtle).frame(height: 1), alignment: .bottom)
        .onHover { hovering = $0 }
    }

    private var display: some View {
        CardColumns(
            star: star.padding(.top, -3),
            number: numberLabel,
            front: cardText(card.front, color: .textPrimary),
            back: cardText(card.back, color: .textSecondary),
            actions: HStack(spacing: 2) {
                iconButton("pencil", help: "Edit card (or double-click)", label: "Edit card \(number)") {
                    model.beginEditing(card.id)
                }
                deleteButton
            }
        )
    }

    private var editor: some View {
        CardColumns(
            star: star.padding(.top, 1),
            number: numberLabel.padding(.top, 5),
            front: field(.front, text: card.front),
            back: field(.back, text: card.back),
            actions: HStack(spacing: 2) {
                iconButton("checkmark", help: "Done (Return). Esc undoes changes.", label: "Done editing card \(number)") {
                    model.finishEditing()
                }
                deleteButton
            }
            .padding(.top, 2)
        )
    }

    private var star: some View { StarButton(card: card, name: "card \(number)") }

    private var numberLabel: some View {
        Text("\(number)").font(.mono(12)).foregroundColor(.textMuted).padding(.top, 1)
    }

    private func cardText(_ text: String, color: Color) -> some View {
        Text(text.isEmpty ? "Empty" : text)
            .font(.system(size: 13))
            .foregroundColor(text.isEmpty ? .textMuted : color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var deleteButton: some View {
        TrashButton(help: "Delete card (Cmd+Z undoes)", label: "Delete card \(number)") {
            model.deleteCard(card.id)
        }
    }

    private func iconButton(_ symbol: String, help: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 14, height: 14)
        }
        .buttonStyle(GhostButtonStyle())
        .help(help)
        .accessibilityLabel(label)
    }

    private func field(_ side: EditField.Side, text: String) -> some View {
        let field = EditField(cardID: card.id, side: side)
        let focused = model.editFocus == field
        return CardTextView(
            text: text, isFocused: focused,
            onChange: { [model] in model.setCardText(field.cardID, side: side, $0) },
            onFocusChange: { [model] in model.editFieldFocusChanged(field, focused: $0) },
            onTab: { [model] _ in model.focusEditField(EditField(cardID: field.cardID, side: side == .front ? .back : .front)) },
            onSubmit: { [model] in model.finishEditing() },
            onCancel: { [model] in model.cancelEditing() }
        )
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            Text(side == .front ? "Front" : "Back")
                .font(.system(size: 13))
                .foregroundColor(.textMuted)
                .padding(.leading, 8)
                .padding(.top, 5)
                .opacity(text.isEmpty ? 1 : 0)
                .allowsHitTesting(false),
            alignment: .topLeading
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .strokeBorder(focused ? palette.focus : .borderStrong, lineWidth: focused ? 2 : 1)
        )
        .accessibilityLabel("Card \(number) \(side == .front ? "front" : "back")")
    }
}

private struct AddCardButton: View {
    let lessonID: UUID
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button { model.addCard(to: lessonID) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                Text("Add card").font(.system(size: 13))
            }
        }
        .buttonStyle(GhostButtonStyle())
        .help("Add a card to this lesson (Cmd+N when a lesson is selected)")
        .padding(.leading, CardRow.inset - 4)
        .padding(.vertical, 6)
    }
}
