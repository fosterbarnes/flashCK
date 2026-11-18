import AppKit
import SwiftUI
import flashCKCore

/// Subjects and their lessons. Custom rows because `List` can't be
/// restyled on macOS 12.
struct Sidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let library = model.library
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    SectionLabel(title: "Subjects")
                    Spacer(minLength: 4)
                    TrashButton(help: "Delete the selected subject or lesson (Delete key)", action: deleteSelection)
                        .disabled(selectedItem == nil)
                        .opacity(selectedItem == nil ? 0.4 : 1)
                }
                ForEach(library.sortedSubjects) { subject in
                    // Subjects and lessons named in the main panel slide in from that side.
                    subjectRow(subject).transition(.move(edge: .trailing).combined(with: .opacity))
                    if model.prefs.expandedSubjectIDs.contains(subject.id) {
                        ForEach(library.lessons(inSubject: subject.id)) {
                            lessonRow($0).transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(8)
        }
        .panel(padding: 0)
        .mainWindowKeys(model) { event in
            // Delete or forward delete acts like the header - button.
            guard event.keyCode == KeyCode.delete || event.keyCode == KeyCode.forwardDelete,
                  !event.isARepeat, selectedItem != nil else { return false }
            deleteSelection()
            return true
        }
    }

    private func subjectRow(_ subject: Subject) -> some View {
        let id = subject.id
        let expanded = model.prefs.expandedSubjectIDs.contains(id)
        return SidebarRow(
            title: subject.name, count: model.library.cardCount(for: .subject(id)),
            isSelected: model.prefs.scope == .subject(id),
            kind: .subject(expanded: expanded, toggle: { model.toggleSubjectExpanded(id) }),
            renameTarget: .subject(id),
            delete: { confirmDelete(.subject(subject)) }
        ) { model.select(.subject(id)) }
        .help("Show the cards of every lesson in this subject. Right-click to rename or delete it.")
        .contextMenu {
            Button("Rename") { model.beginRename(.subject(id)) }
            Button("New Lesson") { model.beginNewLesson(in: id) }
            Divider()
            Button("Delete…") { confirmDelete(.subject(subject)) }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let id = lesson.id
        return SidebarRow(
            title: lesson.name, count: lesson.cards.count, isSelected: model.prefs.scope == .lesson(id),
            kind: .lesson, renameTarget: .lesson(id),
            delete: { confirmDelete(.lesson(lesson)) }
        ) { model.select(.lesson(id)) }
        .help("Right-click to rename, move, or delete this lesson")
        .contextMenu {
            Button("Rename") { model.beginRename(.lesson(id)) }
            Menu("Move to") {
                ForEach(model.library.sortedSubjects) { subject in
                    Button(subject.name) { model.moveLesson(id, to: subject.id) }
                        .disabled(lesson.subjectID == subject.id)
                }
            }
            Divider()
            Button("Delete…") { confirmDelete(.lesson(lesson)) }
        }
    }

    // MARK: - Delete confirmation

    /// Selected subject or lesson, if it still exists.
    private var selectedItem: DeleteItem? {
        switch model.prefs.scope {
        case .all: return nil
        case .subject(let id): return model.library.subject(id: id).map { .subject($0) }
        case .lesson(let id): return model.library.lesson(id: id).map { .lesson($0) }
        }
    }

    private func deleteSelection() {
        if let item = selectedItem { confirmDelete(item) }
    }

    /// AppKit sheet so Delete is the default button (Return confirms, Esc cancels); a SwiftUI alert
    /// cannot make its Delete button the default on macOS 12.
    private func confirmDelete(_ item: DeleteItem) {
        guard let window = model.mainWindow, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title(for: item)
        alert.informativeText = message(for: item)
        // Not `hasDestructiveAction`: AppKit then drops the default button, so Return does nothing.
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { delete(item) }
        }
    }

    private enum DeleteItem {
        case subject(Subject), lesson(Lesson)
    }

    private func title(for item: DeleteItem) -> String {
        switch item {
        case .subject(let subject): return "Delete subject \"\(subject.name)\"?"
        case .lesson(let lesson): return "Delete lesson \"\(lesson.name)\"?"
        }
    }

    /// "Its 2 lessons and 5 cards are deleted too.", "Its 1 card is deleted too.", or nothing when empty.
    private func message(for item: DeleteItem) -> String {
        let library = model.library
        let counts: [(Int, String)]
        switch item {
        case .subject(let subject):
            counts = [(library.lessons(inSubject: subject.id).count, "lesson"),
                      (library.cardCount(for: .subject(subject.id)), "card")]
        case .lesson(let lesson):
            counts = [(library.lesson(id: lesson.id)?.cards.count ?? 0, "card")]
        }
        let parts = counts.filter { $0.0 > 0 }
        let undo = "This cannot be undone."
        guard !parts.isEmpty else { return undo }
        let names = parts.map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }.joined(separator: " and ")
        let verb = parts.count == 1 && parts[0].0 == 1 ? "is" : "are"
        return "Its \(names) \(verb) deleted too. \(undo)"
    }

    private func delete(_ item: DeleteItem) {
        switch item {
        case .subject(let subject): model.deleteSubject(subject.id)
        case .lesson(let lesson): model.deleteLesson(lesson.id)
        }
    }
}

private struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundColor(.textMuted)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
}

private struct SidebarRow: View {
    enum Kind {
        case lesson, subject(expanded: Bool, toggle: () -> Void)
    }

    let title: String
    let count: Int
    let isSelected: Bool
    let kind: Kind
    let renameTarget: RenameTarget
    /// Shows a trash button on hover that deletes this row's subject or lesson (after confirming).
    let delete: () -> Void
    let action: () -> Void
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            if case .subject(let expanded, let toggle) = kind {
                Button(action: toggle) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(isSelected ? .textPrimary : palette.highlight)
                .padding(.leading, 4)
                .help("Show or hide this subject")
            }
            if model.renaming == renameTarget {
                RenameField(initial: title) { [model, renameTarget] name in
                    model.endRename(renameTarget)
                    model.commitRename(renameTarget, to: name)
                } cancel: { [model, renameTarget] in model.endRename(renameTarget) }
                    .padding(.leading, leadingPad - 4)
                    .padding(.trailing, 4)
                    .padding(.vertical, 2)
            } else {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 13, weight: isSubject ? .semibold : .regular))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(count)")
                            .font(.mono(12))
                            .foregroundColor(isSelected ? .textSecondary : .textMuted)
                    }
                    .padding(.leading, leadingPad)
                    .padding(.trailing, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if hovering {
                    TrashButton(help: isSubject ? "Delete this subject" : "Delete this lesson", action: delete)
                        .padding(.trailing, 4)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .fill(isSelected ? palette.accentStrong : hovering ? Color.hover : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .strokeBorder(isSelected ? palette.accentBorder : .clear)
        )
        .onHover { hovering = $0 }
    }

    private var isSubject: Bool {
        if case .subject = kind { return true }
        return false
    }

    private var leadingPad: CGFloat {
        switch kind {
        case .subject: return 2
        case .lesson: return 26
        }
    }

    private var textColor: Color {
        if isSelected { return .textPrimary }
        if isSubject { return palette.highlight }
        return .textSecondary
    }
}
