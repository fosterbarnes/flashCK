import Foundation

public enum ThemeID: String, Codable, CaseIterable, Sendable { case mint, purple }
/// Cards is the card list; Study is the flip card.
public enum StudyTab: String, Codable, CaseIterable, Sendable { case cards, study }

public struct Preferences: Codable, Equatable, Sendable {
    public var theme = ThemeID.mint
    public var scope = StudyScope.all
    public var tab = StudyTab.cards
    public var shuffle = false
    public var backFirst = false
    /// Cards and Study show only starred cards.
    public var starredOnly = false
    public var expandedSubjectIDs: Set<UUID> = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case theme, scope, tab, shuffle, backFirst, starredOnly, expandedSubjectIDs
    }
    private enum LegacyKeys: String, CodingKey { case expandedFolderIDs }

    /// Every field is optional so older or partial files still load. Add new fields the same way.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        // An unknown theme, scope, or removed tab (memorize, cram, edit) resets only that field.
        theme = (try? c.decodeIfPresent(ThemeID.self, forKey: .theme)) ?? d.theme
        scope = (try? c.decodeIfPresent(StudyScope.self, forKey: .scope)) ?? d.scope
        tab = (try? c.decodeIfPresent(StudyTab.self, forKey: .tab)) ?? d.tab
        shuffle = try c.decodeIfPresent(Bool.self, forKey: .shuffle) ?? d.shuffle
        backFirst = try c.decodeIfPresent(Bool.self, forKey: .backFirst) ?? d.backFirst
        starredOnly = try c.decodeIfPresent(Bool.self, forKey: .starredOnly) ?? d.starredOnly
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        expandedSubjectIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .expandedSubjectIDs)
            ?? legacy.decodeIfPresent(Set<UUID>.self, forKey: .expandedFolderIDs) ?? d.expandedSubjectIDs
    }

    /// Drops IDs the library no longer has; a missing selection (or `all`) becomes the first subject.
    public func normalized(for library: Library) -> Preferences {
        var p = self
        p.expandedSubjectIDs = expandedSubjectIDs.intersection(library.subjects.map(\.id))
        switch scope {
        case .all: break
        case .subject(let id): if library.subject(id: id) == nil { p.scope = .all }
        case .lesson(let id): if library.lesson(id: id) == nil { p.scope = .all }
        }
        if p.scope == .all, let first = library.sortedSubjects.first { p.scope = .subject(first.id) }
        return p
    }
}

public struct PreferencesStore: Sendable {
    public let paths: DataPaths

    public init(paths: DataPaths = .standard) { self.paths = paths }

    /// Defaults when the file is missing or unreadable.
    public func load() -> Preferences {
        guard let data = try? Data(contentsOf: paths.preferencesURL),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return prefs
    }

    public func save(_ prefs: Preferences) throws {
        try FileManager.default.createDirectory(at: paths.folder, withIntermediateDirectories: true)
        try encodeJSON(prefs).write(to: paths.preferencesURL, options: .atomic)
    }
}
