import AppKit
import SwiftUI
import flashCKCore

enum LoadState: Equatable {
    case ready
    case failed(String)
}

enum RenameTarget: Equatable {
    case subject(UUID), lesson(UUID)
}

/// What the main panel is creating. The item exists only once it is named.
enum NewItem: Equatable {
    case subject
    /// A lesson for the chosen subject (changeable in the panel).
    case lesson(subjectID: UUID)
    /// A card for the chosen lesson. The user picks the subject, then the lesson (nil until picked).
    case card(subjectID: UUID, lessonID: UUID?)
}

struct EditField: Equatable {
    enum Side { case front, back }
    let cardID: UUID
    let side: Side
}

/// The card open for inline editing in the Cards list, and its text before editing (Esc restores it).
struct CardEdit: Equatable {
    let cardID: UUID
    let original: Card
}

/// The one app state. Views read it and change it only through these methods.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var library = Library()
    @Published private(set) var prefs = Preferences()
    @Published private(set) var loadState = LoadState.ready
    @Published private(set) var saveError: String?
    @Published private(set) var cardsSession: CardsSession?
    /// Which way each study card slid, read by the card transition while it runs.
    let cardSlides = CardSlides()
    /// The sidebar row being renamed in place (the header title keeps its own state).
    @Published private(set) var renaming: RenameTarget?
    @Published private(set) var creating: NewItem?
    @Published private(set) var editing: CardEdit?
    @Published private(set) var editFocus: EditField?
    weak var mainWindow: NSWindow?

    let paths: DataPaths
    private let libraryStore: LibraryStore
    private let prefsStore: PreferencesStore
    /// Card IDs of the current selection, in study order before any shuffle.
    private var studyIDs: [UUID] = []
    /// What the session was built for; a change starts a fresh session.
    private var studyKey: StudyKey?
    private var pending = PendingWrites()
    private var saveTask: Task<Void, Never>?

    init(paths: DataPaths = .standard) {
        self.paths = paths
        libraryStore = LibraryStore(paths: paths)
        prefsStore = PreferencesStore(paths: paths)
        do {
            if let loaded = try libraryStore.load() {
                library = loaded.library
                pending.backup = true
                pending.library = loaded.migrated
            }
        } catch {
            // Nothing writes library.json after a failed load (see flush).
            loadState = .failed(error.localizedDescription)
            return
        }
        prefs = prefsStore.load().normalized(for: library)
        refreshStudy()
        flush()
    }

    // MARK: - Derived state

    var isReady: Bool { loadState == .ready }
    var palette: Palette { .of(prefs.theme) }
    /// Cards in the selection, only the starred ones while `starredOnly` is on.
    var studyCards: [Card] {
        let cards = library.cards(for: prefs.scope)
        return prefs.starredOnly ? cards.filter(\.starred) : cards
    }
    var selectedLessonID: UUID? { prefs.scope.lessonID }

    /// Where New Card (Cmd+N) adds: the selected lesson, else the lesson of the card being edited.
    var newCardLessonID: UUID? {
        selectedLessonID ?? editing.flatMap { library.lessonID(ofCard: $0.cardID) }
    }

    /// The selected subject, or the subject of the selected lesson. New lessons go here.
    var selectedSubjectID: UUID? {
        switch prefs.scope {
        case .all: return nil
        case .subject(let id): return id
        case .lesson(let id): return library.lesson(id: id)?.subjectID
        }
    }

    var selectionName: String {
        switch prefs.scope {
        case .all: return ""
        case .subject(let id): return library.subject(id: id)?.name ?? ""
        case .lesson(let id): return library.lesson(id: id)?.name ?? ""
        }
    }

    // MARK: - Preferences

    /// Also closes an open sidebar rename, which commits it (see RenameField).
    func select(_ scope: StudyScope) {
        finishEditing()
        creating = nil
        renaming = nil
        updatePrefs { $0.scope = scope }
    }

    func toggleShuffle() { updatePrefs { $0.shuffle.toggle() } }
    func toggleBackFirst() { updatePrefs { $0.backFirst.toggle() } }
    func setStarredOnly(_ on: Bool) { updatePrefs { $0.starredOnly = on } }
    func toggleSubjectExpanded(_ id: UUID) { updatePrefs { $0.expandedSubjectIDs.formSymmetricDifference([id]) } }
    func setTheme(_ theme: ThemeID) { updatePrefs { $0.theme = theme } }

    func setTab(_ tab: StudyTab) {
        if tab != .cards { finishEditing() }
        creating = nil
        updatePrefs { $0.tab = tab }
    }

    // MARK: - Subjects, lessons

    /// New Subject (button or menu): name the subject in the main panel before it is created.
    func beginNewSubject() {
        guard isReady else { return }
        finishEditing()
        creating = .subject
    }

    /// New Lesson (button, menu, or subject right-click): pick a subject and name the lesson in the main
    /// panel. Starts on `subjectID`, else the selected subject, else the first one. No-op without subjects.
    func beginNewLesson(in subjectID: UUID? = nil) {
        guard isReady, let id = subjectID ?? selectedSubjectID ?? library.sortedSubjects.first?.id else { return }
        finishEditing()
        creating = .lesson(subjectID: id)
    }

    func setNewLessonSubject(_ subjectID: UUID) {
        guard case .lesson = creating, library.subject(id: subjectID) != nil else { return }
        creating = .lesson(subjectID: subjectID)
    }

    /// New Card (button): pick a subject and a lesson in the main panel, then add the card there.
    /// Starts on the selected lesson, else the selected subject (lesson unpicked). No-op without lessons.
    func beginNewCard() {
        guard isReady, !library.lessons.isEmpty else { return }
        finishEditing()
        let subjectID = selectedSubjectID.flatMap { library.lessons(inSubject: $0).isEmpty ? nil : $0 }
            ?? library.orderedLessons[0].subjectID
        let lessonID = selectedLessonID.flatMap { library.lesson(id: $0)?.subjectID == subjectID ? $0 : nil }
        creating = .card(subjectID: subjectID, lessonID: lessonID)
    }

    /// Changing the subject clears the lesson choice.
    func setNewCardSubject(_ subjectID: UUID) {
        guard case .card(let current, _) = creating, current != subjectID, library.subject(id: subjectID) != nil
        else { return }
        creating = .card(subjectID: subjectID, lessonID: nil)
    }

    func setNewCardLesson(_ lessonID: UUID) {
        guard case .card(let subjectID, _) = creating, library.lesson(id: lessonID)?.subjectID == subjectID
        else { return }
        creating = .card(subjectID: subjectID, lessonID: lessonID)
    }

    /// Selects the chosen lesson and opens a new card in it for editing.
    func addChosenCard() {
        guard case .card(let subjectID, let lessonID?) = creating, library.lesson(id: lessonID) != nil else { return }
        creating = nil
        updatePrefs {
            $0.scope = .lesson(lessonID)
            $0.expandedSubjectIDs.insert(subjectID)
        }
        addCard(to: lessonID)
    }

    func cancelCreating() { creating = nil }

    func addSubject(named name: String) {
        guard isReady else { return }
        creating = nil
        let id = updateLibrary { $0.addSubject(name: name) }
        updatePrefs { $0.scope = .subject(id) }
    }

    func addLesson(inSubject subjectID: UUID, named name: String) {
        guard isReady, let id = updateLibrary({ $0.addLesson(name: name, subjectID: subjectID) }) else { return }
        creating = nil
        updatePrefs {
            $0.scope = .lesson(id)
            $0.expandedSubjectIDs.insert(subjectID)
        }
    }

    func moveLesson(_ id: UUID, to subjectID: UUID) {
        updateLibrary { $0.moveLesson(id, to: subjectID) }
        updatePrefs { $0.expandedSubjectIDs.insert(subjectID) }
    }

    func beginRename(_ target: RenameTarget) { renaming = target }

    /// Closes the sidebar field for `target` only, so a field that already moved on stays open.
    func endRename(_ target: RenameTarget) {
        if renaming == target { renaming = nil }
    }

    func commitRename(_ target: RenameTarget, to name: String) {
        updateLibrary { library in
            switch target {
            case .subject(let id): library.renameSubject(id, to: name)
            case .lesson(let id): library.renameLesson(id, to: name)
            }
        }
    }

    func deleteSubject(_ id: UUID) { updateLibrary { $0.deleteSubject(id) } }
    /// Deleting the selected lesson selects its subject.
    func deleteLesson(_ id: UUID) {
        if prefs.scope == .lesson(id), let subjectID = library.lesson(id: id)?.subjectID {
            updatePrefs { $0.scope = .subject(subjectID) }
        }
        updateLibrary { $0.deleteLesson(id) }
    }

    // MARK: - Cards

    /// New card in `newCardLessonID`; without one, the subject and lesson picker (`beginNewCard`).
    func addCard() {
        guard let lessonID = newCardLessonID else { return beginNewCard() }
        addCard(to: lessonID)
    }

    /// Appends a blank card, shows the Cards list, and opens the card for editing. While `starredOnly`
    /// is on the card starts starred, so it stays in the list.
    func addCard(to lessonID: UUID) {
        guard isReady else { return }
        finishEditing()
        let starred = prefs.starredOnly
        guard let id = updateLibrary({ $0.addCard(to: lessonID, starred: starred) }) else { return }
        setTab(.cards)
        beginEditing(id)
    }

    func setCardText(_ id: UUID, side: EditField.Side, _ text: String) {
        updateLibrary { library in
            switch side {
            case .front: library.updateCard(id: id, front: text)
            case .back: library.updateCard(id: id, back: text)
            }
        }
    }

    func toggleStar(_ id: UUID) { updateLibrary { $0.toggleStar(id: id) } }

    /// Deletes at once; Cmd+Z (window undo manager) puts the card back at the same index.
    func deleteCard(_ id: UUID) {
        if editing?.cardID == id { clearEditing() }
        // Drop text focus so the next Cmd+Z reaches the window's undo manager, not a text field's.
        mainWindow?.makeFirstResponder(nil)
        // A blank card has nothing to bring back; undoing would leave an empty card behind.
        guard let deleted = updateLibrary({ $0.deleteCard(id: id) }), !deleted.card.isBlank,
              let undo = mainWindow?.undoManager else { return }
        undo.registerUndo(withTarget: self) { $0.restoreCard(deleted) }
        undo.setActionName("Delete Card")
    }

    private func restoreCard(_ deleted: DeletedCard) {
        updateLibrary { $0.restore(deleted) }
        guard let undo = mainWindow?.undoManager else { return }
        undo.registerUndo(withTarget: self) { $0.deleteCard(deleted.card.id) }
        undo.setActionName("Delete Card")
    }

    // MARK: - Inline editing

    /// Opens a card for editing (one at a time; any other open card finishes first).
    func beginEditing(_ cardID: UUID, side: EditField.Side = .front) {
        if editing?.cardID != cardID {
            finishEditing()
            guard let card = library.card(id: cardID) else { return }
            editing = CardEdit(cardID: cardID, original: card)
        }
        editFocus = EditField(cardID: cardID, side: side)
    }

    /// Keeps the text (it is saved as you type). A card left blank is removed.
    func finishEditing() {
        guard let edit = editing else { return }
        clearEditing()
        if library.card(id: edit.cardID)?.isBlank == true { updateLibrary { $0.deleteCard(id: edit.cardID) } }
    }

    /// Puts the text back as it was; a new card is removed.
    func cancelEditing() {
        guard let edit = editing else { return }
        clearEditing()
        let original = edit.original
        updateLibrary { library in
            if original.isBlank {
                library.deleteCard(id: original.id)
            } else {
                library.updateCard(id: original.id, front: original.front, back: original.back)
            }
        }
    }

    private func clearEditing() {
        editing = nil
        editFocus = nil
        mainWindow?.makeFirstResponder(nil)
    }

    func focusEditField(_ field: EditField) { editFocus = field }

    /// Called by CardTextView when it gains or loses first responder.
    func editFieldFocusChanged(_ field: EditField, focused: Bool) {
        if focused {
            if editFocus != field { editFocus = field }
        } else if editFocus == field {
            editFocus = nil
        }
    }

    // MARK: - Study

    func flip() {
        guard prefs.tab == .study, cardsSession?.current != nil else { return }
        cardsSession?.flipped.toggle()
    }

    func nextCard() { moveCard(forward: true) }
    func previousCard() { moveCard(forward: false) }

    /// Steps the session with a slide: the current card leaves one side as the next arrives from the other.
    private func moveCard(forward: Bool) {
        guard let session = cardsSession, session.canStep, let leaving = session.current else { return }
        cardSlides.record(leaving: leaving, forward: forward)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduceMotion ? nil : .easeInOut(duration: Metrics.cardSlideDuration)) {
            forward ? cardsSession?.next() : cardsSession?.previous()
        }
    }

    /// Left/Right keys: previous/next card in Study.
    func studyArrow(right: Bool) {
        guard prefs.tab == .study else { return }
        right ? nextCard() : previousCard()
    }

    /// Quit: drops a card still left blank, then writes everything. `saveError` says what did not save.
    func prepareToQuit() {
        finishEditing()
        flush()
    }

    // MARK: - State flow

    private func updatePrefs(_ change: (inout Preferences) -> Void) {
        var next = prefs
        change(&next)
        next = next.normalized(for: library)
        guard next != prefs else { return }
        prefs = next
        pending.preferences = true
        refreshStudy()
        scheduleSave()
    }

    @discardableResult
    private func updateLibrary<T>(_ change: (inout Library) -> T) -> T {
        let result = change(&library)
        pending.library = true
        if let edit = editing, library.card(id: edit.cardID) == nil {
            editing = nil
            editFocus = nil
        }
        switch renaming {
        case .subject(let id) where library.subject(id: id) == nil: renaming = nil
        case .lesson(let id) where library.lesson(id: id) == nil: renaming = nil
        default: break
        }
        switch creating {
        case .lesson(let subjectID) where library.subject(id: subjectID) == nil:
            creating = nil
        case .card(let subjectID, _) where library.subject(id: subjectID) == nil:
            creating = nil
        case .card(let subjectID, let lessonID?) where library.lesson(id: lessonID)?.subjectID != subjectID:
            creating = .card(subjectID: subjectID, lessonID: nil)
        default:
            break
        }
        let normalized = prefs.normalized(for: library)
        if normalized != prefs {
            prefs = normalized
            pending.preferences = true
        }
        refreshStudy()
        scheduleSave()
        return result
    }

    /// Drops the session when the selection, Shuffle, `starredOnly`, or the study cards change, then builds
    /// it while Study is showing. Text edits keep the session. Cards that only left (unstarred under Starred
    /// only, or deleted) or changed order (a rename or move) are followed in place, so studying goes on
    /// from the same card.
    private func refreshStudy() {
        let ids = studyCards.map(\.id)
        let key = StudyKey(scope: prefs.scope, shuffle: prefs.shuffle, starredOnly: prefs.starredOnly)
        if key != studyKey {
            studyKey = key
            cardsSession = nil
        } else if ids != studyIDs {
            if Set(ids).isSubset(of: studyIDs) {
                cardsSession?.update(to: ids)
            } else {
                cardsSession = nil
            }
        }
        studyIDs = ids
        if prefs.tab == .study, cardsSession == nil {
            cardsSession = CardsSession(cardIDs: ids, shuffled: prefs.shuffle)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes whatever changed. Each failure shows in the save banner; Retry calls this again.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isReady else { return }
        let errors = pending.flush(library, prefs, libraryStore: libraryStore, preferencesStore: prefsStore)
        let message = errors.isEmpty ? nil : errors.joined(separator: "\n")
        if saveError != message { saveError = message }
    }
}

private struct StudyKey: Equatable {
    let scope: StudyScope
    let shuffle: Bool
    let starredOnly: Bool
}
