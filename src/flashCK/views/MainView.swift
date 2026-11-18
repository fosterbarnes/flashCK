import SwiftUI
import flashCKCore

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        content
            .padding(Metrics.pageMargin)
            .frame(minWidth: 760, idealWidth: 960, minHeight: 520, idealHeight: 640)
            .background(Color.appBackground)
            .foregroundColor(.textPrimary)
            .background(WindowChrome(onWindow: { [model] in model.mainWindow = $0 }))
    }

    @ViewBuilder private var content: some View {
        switch model.loadState {
        case .failed(let message):
            LoadErrorView(message: message)
        case .ready:
            HStack(alignment: .top, spacing: Metrics.pageMargin) {
                VStack(spacing: Metrics.pageMargin) {
                    Sidebar()
                    ActionsPanel()
                }
                .frame(width: Metrics.sidebarWidth)
                VStack(alignment: .leading, spacing: 10) {
                    if let error = model.saveError { SaveErrorBar(message: error) }
                    Header()
                    TabStrip(items: Self.tabs, selection: model.prefs.tab) { model.setTab($0) }
                    ZStack {
                        panel.id(model.prefs.tab).transition(.opacity)
                    }
                    .animation(.easeInOut(duration: Metrics.fadeDuration), value: model.prefs.tab)
                }
            }
        }
    }

    private static let tabs: [TabItem<StudyTab>] = [
        TabItem(id: .cards, title: "Cards"),
        TabItem(id: .study, title: "Study"),
    ]

    private var panel: some View {
        Group {
            if model.creating != nil || model.library.lessons.isEmpty {
                NoLessonsView()
            } else {
                switch model.prefs.tab {
                case .cards: CardsTab()
                case .study: StudyCardsTab()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panel()
    }
}

/// No lessons in the selection, no subjects at all, or a new subject, lesson, or card being created: a short
/// hint, a sample list (or the subject and lesson choices), and the name entry (or the add button).
struct NoLessonsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            switch model.creating {
            case .subject:
                hint("New subject", "Name it to add it to the sidebar.")
                subjectEntry
            case .lesson(let subjectID):
                hint("New lesson", "Pick its subject, then name it.")
                ChoiceList(title: "Subject", items: subjectItems, selection: subjectID, isSubject: true,
                           help: { "Add the lesson to \($0)" }) { model.setNewLessonSubject($0) }
                lessonEntry(subjectID)
            case .card(let subjectID, let lessonID):
                hint("New card", "Pick its subject and lesson, then add it.")
                cardEntry(subjectID: subjectID, lessonID: lessonID)
            case nil:
                if let subjectID = model.selectedSubjectID ?? model.library.sortedSubjects.first?.id {
                    let name = model.library.subject(id: subjectID)?.name ?? ""
                    hint("No lessons yet", "Add one to \(name) to start making cards.")
                    NamesExample(title: "Example lessons", names: Self.lessons, isSubject: false)
                    lessonEntry(subjectID).id(subjectID)
                } else {
                    hint("No subjects yet", "Create one to get started.")
                    subjectEntry
                }
            }
        }
    }

    @ViewBuilder private var subjectEntry: some View {
        NamesExample(title: "Example subjects", names: Self.subjects, isSubject: true)
        NameEntry(placeholder: "Subject name", button: "+ Subject", help: "Create a subject, such as a language",
                  cancel: cancel) { name in
            withAnimation(slide) { model.addSubject(named: name) }
        }
    }

    /// Not keyed by subject while creating, so changing the subject keeps the typed name.
    private func lessonEntry(_ subjectID: UUID) -> some View {
        let name = model.library.subject(id: subjectID)?.name ?? ""
        return NameEntry(placeholder: "Lesson name", button: "+ Lesson", help: "Create a lesson in \(name)",
                         cancel: cancel) { lesson in
            withAnimation(slide) { model.addLesson(inSubject: subjectID, named: lesson) }
        }
    }

    /// New sidebar rows slide in from the panel, unless Reduce Motion is on.
    private var slide: Animation? { reduceMotion ? nil : .easeOut(duration: Metrics.slideDuration) }

    private var subjectItems: [ChoiceItem] {
        model.library.sortedSubjects.map { ChoiceItem(id: $0.id, name: $0.name) }
    }

    @ViewBuilder private func cardEntry(subjectID: UUID, lessonID: UUID?) -> some View {
        let lessons = model.library.lessons(inSubject: subjectID).map { ChoiceItem(id: $0.id, name: $0.name) }
        ChoiceList(title: "Subject", items: subjectItems, selection: subjectID, isSubject: true,
                   help: { "Choose a lesson in \($0)" }) { model.setNewCardSubject($0) }
        if lessons.isEmpty {
            Text("No lessons in this subject")
                .font(.system(size: 12))
                .foregroundColor(.textMuted)
        } else {
            ChoiceList(title: "Lesson", items: lessons, selection: lessonID, isSubject: false,
                       help: { "Add the card to \($0)" }) { model.setNewCardLesson($0) }
        }
        HStack(spacing: 8) {
            Button("Cancel") { model.cancelCreating() }
                .buttonStyle(NeutralButtonStyle())
                .help("Close without creating (Esc)")
            Button("+ Card") { model.addChosenCard() }
                .buttonStyle(AccentButtonStyle())
                .disabled(lessonID == nil)
                .help(lessonID == nil ? "Pick a lesson first" : "Add a card to this lesson (Return)")
        }
        .mainWindowKeys(model) { [weak model] event in
            guard let model else { return false }
            switch event.keyCode {
            case KeyCode.escape: model.cancelCreating()
            case KeyCode.returnKey, KeyCode.enter: model.addChosenCard()
            default: return false
            }
            return true
        }
    }

    /// Only an entry the user opened (New Subject / New Lesson / New Card) can be closed.
    private var cancel: (() -> Void)? {
        model.creating == nil ? nil : { [model] in model.cancelCreating() }
    }

    // Each list holds one level only, so it is clear what to type into the new item.
    private static let subjects = ["French", "Latin", "Spanish", "Math", "Snoopy"]
    private static let lessons = ["Greetings", "Verbs", "Chapter 3", "Fractions"]

    private func hint(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title).foregroundColor(.textSecondary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)
        }
    }
}

/// Name field plus add button for the empty screens, so the first subject or lesson is named where
/// the user is already looking. Return or the button adds; the button is dim while the name is blank.
/// With `cancel`, Esc anywhere in the window or a Cancel button closes the entry.
private struct NameEntry: View {
    let placeholder: String
    let button: String
    let help: String
    var cancel: (() -> Void)?
    let add: (String) -> Void
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @FocusState private var focused: Bool
    @State private var text = ""

    var body: some View {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(width: 180)
                .background(RoundedRectangle(cornerRadius: Metrics.smallRadius).fill(Color.appBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.smallRadius)
                        .strokeBorder(focused ? palette.focus : .borderStrong, lineWidth: focused ? 2 : 1)
                )
                .focused($focused)
                .onSubmit { if !name.isEmpty { add(name) } }
                .onExitCommand { cancel?() }
                .accessibilityLabel(placeholder)
            HStack(spacing: 8) {
                if let cancel {
                    Button("Cancel", action: cancel)
                        .buttonStyle(NeutralButtonStyle())
                        .help("Close without creating (Esc)")
                }
                Button(button) { add(name) }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(name.isEmpty)
                    .help(help)
            }
        }
        .onAppear {
            // Not while a sidebar rename is open, unless the user asked for this entry (+ or New Subject):
            // taking focus ends the rename. Next turn for macOS 12.
            guard model.renaming == nil || model.creating != nil else { return }
            Task { @MainActor in focused = true }
        }
        // Esc from anywhere in the window; while the field is focused the monitor passes keys on and
        // onExitCommand handles it.
        .mainWindowKeys(model) { event in
            guard event.keyCode == KeyCode.escape, let cancel else { return false }
            cancel()
            return true
        }
    }
}

private struct ChoiceItem: Identifiable {
    let id: UUID
    let name: String
}

/// Subject or lesson list for a new lesson or card, styled like the example box; the choice is highlighted.
private struct ChoiceList: View {
    let title: String
    let items: [ChoiceItem]
    let selection: UUID?
    let isSubject: Bool
    let help: (String) -> String
    let select: (UUID) -> Void

    private static let rowHeight: CGFloat = 26
    private static let maxRows = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BoxTitle(title: title)
                .padding(.leading, 6)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        ChoiceRow(name: item.name, isSelected: item.id == selection, isSubject: isSubject,
                                  height: Self.rowHeight, help: help(item.name)) { select(item.id) }
                    }
                }
            }
            .frame(height: Self.rowHeight * CGFloat(min(items.count, Self.maxRows)))
        }
        .padding(6)
        .exampleBox()
    }
}

/// Subjects draw like sidebar subject rows (semibold highlight), lessons like lesson rows.
private struct ChoiceRow: View {
    let name: String
    let isSelected: Bool
    let isSubject: Bool
    let height: CGFloat
    let help: String
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(name)
                    .font(.system(size: 13, weight: isSubject ? .semibold : .regular))
                    .foregroundColor(isSelected ? .textPrimary : isSubject ? palette.highlight : .textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .fill(isSelected ? palette.accentStrong : hovering ? Color.hover : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .strokeBorder(isSelected ? palette.accentBorder : .clear)
        )
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Static sample of subject or lesson names, styled like the matching sidebar rows.
private struct NamesExample: View {
    let title: String
    let names: [String]
    let isSubject: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BoxTitle(title: title)
                .padding(.bottom, 2)
            ForEach(names, id: \.self) { name in
                HStack(spacing: 6) {
                    if isSubject {
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    Text(name).font(.system(size: 13, weight: isSubject ? .semibold : .regular))
                }
                .foregroundColor(isSubject ? palette.highlight : .textSecondary)
            }
        }
        .padding(12)
        .exampleBox()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(names.joined(separator: ", "))")
    }
}

/// Small uppercase heading inside the example and choice boxes.
private struct BoxTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundColor(.textMuted)
    }
}

private extension View {
    /// The 180pt card-surface box shared by the example names and the subject and lesson choices.
    func exampleBox() -> some View {
        frame(width: 180, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.panelRadius).fill(Color.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: Metrics.panelRadius).strokeBorder(Color.borderSubtle))
    }
}

/// Selection has no cards, or none starred while the header switch shows starred cards only.
struct NoCardsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            if model.prefs.starredOnly {
                Text("No starred cards")
                    .foregroundColor(.textSecondary)
                Button("Show all cards") { model.setStarredOnly(false) }
                    .buttonStyle(AccentButtonStyle())
                    .help("Show every card, starred or not")
            } else {
                Text("No cards")
                    .foregroundColor(.textSecondary)
                Button("Add cards") { model.setTab(.cards) }
                    .buttonStyle(AccentButtonStyle())
                    .help("Open the Cards list")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
