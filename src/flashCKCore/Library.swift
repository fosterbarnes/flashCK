import Foundation

public struct Library: Codable, Equatable, Sendable {
    /// 2: folders became subjects (`subjects`, `subjectID`, scope kind `subject`) and tags were removed.
    /// 3: categories became lessons (`lessons`, scope kind `lesson`) and every lesson belongs to a subject.
    /// 4: Memorize and Cram were removed; cards no longer store `cramLevel`.
    /// Older files still load: tag data and Cram levels are dropped, and lessons without a subject move
    /// into a new "Unsorted" subject. These changes are written on the next save.
    public static let currentSchema = 4
    public static let unsortedSubjectName = "Unsorted"
    public var schemaVersion = Library.currentSchema
    public var subjects: [Subject] = []
    public var lessons: [Lesson] = []

    public init(subjects: [Subject] = [], lessons: [Lesson] = []) {
        self.subjects = subjects
        self.lessons = lessons
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, subjects, lessons }
    private enum LegacyKeys: String, CodingKey { case folders, categories }

    /// A lesson as stored by any schema: schema 1 wrote `folderID`, schemas 1-2 allowed no subject.
    private struct StoredLesson: Decodable {
        let id: UUID
        let name: String
        let subjectID: UUID?
        let cards: [Card]

        private enum CodingKeys: String, CodingKey { case id, name, subjectID, folderID, cards }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            subjectID = try c.decodeIfPresent(UUID.self, forKey: .subjectID)
                ?? c.decodeIfPresent(UUID.self, forKey: .folderID)
            cards = try c.decode([Card].self, forKey: .cards)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        schemaVersion = Library.currentSchema
        subjects = try c.decodeIfPresent([Subject].self, forKey: .subjects)
            ?? legacy.decode([Subject].self, forKey: .folders)
        let stored = try c.decodeIfPresent([StoredLesson].self, forKey: .lessons)
            ?? legacy.decode([StoredLesson].self, forKey: .categories)
        let subjectIDs = Set(subjects.map(\.id))
        var unsortedID: UUID?
        for s in stored {
            let subjectID: UUID
            if let id = s.subjectID, subjectIDs.contains(id) {
                subjectID = id
            } else if let id = unsortedID {
                subjectID = id
            } else {
                let unsorted = Subject(name: Library.unsortedSubjectName)
                subjects.append(unsorted)
                unsortedID = unsorted.id
                subjectID = unsorted.id
            }
            lessons.append(Lesson(id: s.id, name: s.name, subjectID: subjectID, cards: s.cards))
        }
    }
}

public struct Subject: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct Lesson: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var subjectID: UUID
    public var cards: [Card]

    public init(id: UUID = UUID(), name: String, subjectID: UUID, cards: [Card] = []) {
        self.id = id
        self.name = name
        self.subjectID = subjectID
        self.cards = cards
    }
}

public struct Card: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var front: String
    public var back: String
    /// Marked by the user; `starredOnly` shows just these. Optional in the file, so older cards load.
    public var starred: Bool

    public init(id: UUID = UUID(), front: String = "", back: String = "", starred: Bool = false) {
        self.id = id
        self.front = front
        self.back = back
        self.starred = starred
    }

    private enum CodingKeys: String, CodingKey { case id, front, back, starred }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        front = try c.decode(String.self, forKey: .front)
        back = try c.decode(String.self, forKey: .back)
        starred = try c.decodeIfPresent(Bool.self, forKey: .starred) ?? false
    }

    /// Both sides empty or whitespace.
    public var isBlank: Bool {
        front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// What is being studied. JSON: {"kind":"all"}, {"kind":"subject","id":...}, {"kind":"lesson","id":...}.
/// Older files wrote "folder" for subjects and "category" for lessons; both still decode.
/// `all` (every card) has no sidebar row; it only remains while there are no subjects (see `Preferences.normalized`).
public enum StudyScope: Codable, Hashable, Sendable {
    case all, subject(UUID), lesson(UUID)

    /// The lesson ID when the scope is one lesson.
    public var lessonID: UUID? {
        if case .lesson(let id) = self { return id }
        return nil
    }

    private enum CodingKeys: String, CodingKey { case kind, id }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "all": self = .all
        case "subject", "folder": self = .subject(try c.decode(UUID.self, forKey: .id))
        case "lesson", "category": self = .lesson(try c.decode(UUID.self, forKey: .id))
        case let kind:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown scope kind \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all: try c.encode("all", forKey: .kind)
        case .subject(let id): try c.encode("subject", forKey: .kind); try c.encode(id, forKey: .id)
        case .lesson(let id): try c.encode("lesson", forKey: .kind); try c.encode(id, forKey: .id)
        }
    }
}
