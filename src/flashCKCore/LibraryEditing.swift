import Foundation

/// A deleted card plus where it was, so undo can put it back.
public struct DeletedCard: Equatable, Sendable {
    public let lessonID: UUID
    public let index: Int
    public let card: Card

    public init(lessonID: UUID, index: Int, card: Card) {
        self.lessonID = lessonID
        self.index = index
        self.card = card
    }
}

private func byName(_ a: String, _ b: String) -> Bool {
    a.localizedStandardCompare(b) == .orderedAscending
}

private func cleaned(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func cleaned(_ name: String, default fallback: String) -> String {
    let n = cleaned(name)
    return n.isEmpty ? fallback : n
}

// MARK: - Queries

extension Library {
    public var sortedSubjects: [Subject] { subjects.sorted { byName($0.name, $1.name) } }

    public func lessons(inSubject subjectID: UUID) -> [Lesson] {
        lessons.filter { $0.subjectID == subjectID }.sorted { byName($0.name, $1.name) }
    }

    /// The one ordering used by sidebar and study: lessons grouped by subject, in subject order.
    public var orderedLessons: [Lesson] {
        sortedSubjects.flatMap { lessons(inSubject: $0.id) }
    }

    public func lessons(for scope: StudyScope) -> [Lesson] {
        switch scope {
        case .all: return orderedLessons
        case .subject(let id): return lessons(inSubject: id)
        case .lesson(let id): return lessons.filter { $0.id == id }
        }
    }

    /// Cards in sidebar order.
    public func cards(for scope: StudyScope) -> [Card] {
        lessons(for: scope).flatMap(\.cards)
    }

    public func cardCount(for scope: StudyScope) -> Int {
        lessons(for: scope).reduce(0) { $0 + $1.cards.count }
    }

    public func card(id: UUID) -> Card? {
        for l in lessons { if let card = l.cards.first(where: { $0.id == id }) { return card } }
        return nil
    }

    public func lessonID(ofCard id: UUID) -> UUID? { location(ofCard: id).map { lessons[$0.0].id } }

    public func subject(id: UUID) -> Subject? { subjects.first { $0.id == id } }
    public func lesson(id: UUID) -> Lesson? { lessons.first { $0.id == id } }

    /// Lesson index and card index for a card ID.
    private func location(ofCard id: UUID) -> (Int, Int)? {
        for (li, l) in lessons.enumerated() {
            if let i = l.cards.firstIndex(where: { $0.id == id }) { return (li, i) }
        }
        return nil
    }

    private mutating func modifyCard(_ id: UUID, _ change: (inout Card) -> Void) {
        guard let (li, i) = location(ofCard: id) else { return }
        change(&lessons[li].cards[i])
    }
}

// MARK: - Mutations

extension Library {
    @discardableResult
    public mutating func addSubject(name: String) -> UUID {
        let subject = Subject(name: cleaned(name, default: "New Subject"))
        subjects.append(subject)
        return subject.id
    }

    public mutating func renameSubject(_ id: UUID, to name: String) {
        let n = cleaned(name)
        guard !n.isEmpty, let i = subjects.firstIndex(where: { $0.id == id }) else { return }
        subjects[i].name = n
    }

    /// Deletes the subject with all its lessons and their cards.
    public mutating func deleteSubject(_ id: UUID) {
        subjects.removeAll { $0.id == id }
        lessons.removeAll { $0.subjectID == id }
    }

    /// Returns nil when the subject does not exist.
    @discardableResult
    public mutating func addLesson(name: String, subjectID: UUID) -> UUID? {
        guard subject(id: subjectID) != nil else { return nil }
        let lesson = Lesson(name: cleaned(name, default: "New Lesson"), subjectID: subjectID)
        lessons.append(lesson)
        return lesson.id
    }

    public mutating func renameLesson(_ id: UUID, to name: String) {
        let n = cleaned(name)
        guard !n.isEmpty, let i = lessons.firstIndex(where: { $0.id == id }) else { return }
        lessons[i].name = n
    }

    /// No-op when the subject does not exist.
    public mutating func moveLesson(_ id: UUID, to subjectID: UUID) {
        guard subject(id: subjectID) != nil, let i = lessons.firstIndex(where: { $0.id == id }) else { return }
        lessons[i].subjectID = subjectID
    }

    public mutating func deleteLesson(_ id: UUID) {
        lessons.removeAll { $0.id == id }
    }

    /// Appends an empty card. Returns nil when the lesson does not exist.
    @discardableResult
    public mutating func addCard(to lessonID: UUID, starred: Bool = false) -> UUID? {
        guard let i = lessons.firstIndex(where: { $0.id == lessonID }) else { return nil }
        let card = Card(starred: starred)
        lessons[i].cards.append(card)
        return card.id
    }

    /// Nil arguments leave that side unchanged.
    public mutating func updateCard(id: UUID, front: String? = nil, back: String? = nil) {
        modifyCard(id) { card in
            if let front { card.front = front }
            if let back { card.back = back }
        }
    }

    public mutating func toggleStar(id: UUID) {
        modifyCard(id) { $0.starred.toggle() }
    }

    @discardableResult
    public mutating func deleteCard(id: UUID) -> DeletedCard? {
        guard let (li, i) = location(ofCard: id) else { return nil }
        let card = lessons[li].cards.remove(at: i)
        return DeletedCard(lessonID: lessons[li].id, index: i, card: card)
    }

    /// Undo for deleteCard. No-op if the lesson is gone.
    public mutating func restore(_ deleted: DeletedCard) {
        guard let li = lessons.firstIndex(where: { $0.id == deleted.lessonID }) else { return }
        let cards = lessons[li].cards
        lessons[li].cards.insert(deleted.card, at: min(deleted.index, cards.count))
    }
}
