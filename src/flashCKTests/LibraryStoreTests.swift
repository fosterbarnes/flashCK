import XCTest
@testable import flashCKCore

final class LibraryStoreTests: XCTestCase {
    private var dir: URL!
    private var store: LibraryStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("flashCKTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = LibraryStore(paths: DataPaths(folder: dir))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileLoadsNil() throws {
        XCTAssertNil(try store.load())
    }

    func testUnreadableJSONThrowsAndLeavesBytes() throws {
        let bytes = Data("{ not json".utf8)
        try bytes.write(to: store.paths.libraryURL)
        XCTAssertThrowsError(try store.load()) { error in
            guard case LibraryStoreError.unreadable = error else { return XCTFail("got \(error)") }
        }
        XCTAssertEqual(try Data(contentsOf: store.paths.libraryURL), bytes)
    }

    func testNewerSchemaThrows() throws {
        let newer = Library.currentSchema + 1
        try Data(#"{"schemaVersion":\#(newer),"futureField":true}"#.utf8).write(to: store.paths.libraryURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? LibraryStoreError, .newerSchema(newer))
        }
    }

    func testSaveLoadRoundTrip() throws {
        var lib = Library()
        let subject = lib.addSubject(name: "Spanish")
        let lesson = try XCTUnwrap(lib.addLesson(name: "Verbs", subjectID: subject))
        let card = try XCTUnwrap(lib.addCard(to: lesson))
        lib.updateCard(id: card, front: "hablar", back: "to speak")
        try store.save(lib)
        let loaded = try XCTUnwrap(try store.load())
        XCTAssertEqual(loaded.library, lib)
        XCTAssertFalse(loaded.migrated)
    }

    func testSchema1LoadsFoldersAsSubjectsAndIgnoresTags() throws {
        let subject = UUID(), cat = UUID(), card = UUID(), tag = UUID()
        let json = #"{"schemaVersion":1,"folders":[{"id":"\#(subject)","name":"Spanish"}],"#
            + #""categories":[{"id":"\#(cat)","name":"Verbs","folderID":"\#(subject)","cards":["#
            + #"{"id":"\#(card)","front":"a","back":"b","cramLevel":2,"tagIDs":["\#(tag)"]}]}],"#
            + #""tags":[{"id":"\#(tag)","name":"noun"}]}"#
        try Data(json.utf8).write(to: store.paths.libraryURL)
        let loaded = try XCTUnwrap(try store.load())
        XCTAssertTrue(loaded.migrated)
        let lib = loaded.library
        XCTAssertEqual(lib.subjects.map(\.id), [subject])
        XCTAssertEqual(lib.lesson(id: cat)?.subjectID, subject)
        XCTAssertEqual(lib.card(id: card), Card(id: card, front: "a", back: "b"))

        let prefsJSON = #"{"scope":{"kind":"folder","id":"\#(subject)"},"expandedFolderIDs":["\#(subject)"],"tagIDs":["\#(tag)"]}"#
        try Data(prefsJSON.utf8).write(to: store.paths.preferencesURL)
        let prefs = PreferencesStore(paths: store.paths).load()
        XCTAssertEqual(prefs.scope, .subject(subject))
        XCTAssertEqual(prefs.expandedSubjectIDs, [subject])
    }

    func testSchema2LoadsCategoriesAsLessonsAndMovesLooseOnesToUnsorted() throws {
        let subject = UUID(), inSubject = UUID(), loose = UUID(), orphan = UUID()
        let json = #"{"schemaVersion":2,"subjects":[{"id":"\#(subject)","name":"French"}],"categories":["#
            + #"{"id":"\#(inSubject)","name":"Verbs","subjectID":"\#(subject)","cards":[]},"#
            + #"{"id":"\#(loose)","name":"Loose","cards":[]},"#
            + #"{"id":"\#(orphan)","name":"Orphan","subjectID":"\#(UUID())","cards":[]}]}"#
        try Data(json.utf8).write(to: store.paths.libraryURL)
        let loaded = try XCTUnwrap(try store.load())
        XCTAssertTrue(loaded.migrated)
        let lib = loaded.library
        XCTAssertEqual(lib.schemaVersion, Library.currentSchema)
        XCTAssertEqual(lib.subjects.count, 2)
        let unsorted = try XCTUnwrap(lib.subjects.first { $0.name == Library.unsortedSubjectName })
        XCTAssertEqual(lib.lesson(id: inSubject)?.subjectID, subject)
        XCTAssertEqual(lib.lesson(id: loose)?.subjectID, unsorted.id)
        XCTAssertEqual(lib.lesson(id: orphan)?.subjectID, unsorted.id)

        let prefsJSON = #"{"scope":{"kind":"category","id":"\#(loose)"}}"#
        try Data(prefsJSON.utf8).write(to: store.paths.preferencesURL)
        XCTAssertEqual(PreferencesStore(paths: store.paths).load().scope, .lesson(loose))
    }

    func testRemovedTabLoadsAsDefaultAndKeepsOtherPreferences() throws {
        for removed in ["cram", "memorize", "edit"] {
            try Data(#"{"theme":"purple","tab":"\#(removed)"}"#.utf8).write(to: store.paths.preferencesURL)
            let prefs = PreferencesStore(paths: store.paths).load()
            XCTAssertEqual(prefs.tab, .cards)
            XCTAssertEqual(prefs.theme, .purple)
        }
    }

    func testUnknownThemeAndScopeKeepOtherPreferences() throws {
        let json = #"{"theme":"blue","scope":{"kind":"folderish"},"shuffle":true,"starredOnly":true}"#
        try Data(json.utf8).write(to: store.paths.preferencesURL)
        let prefs = PreferencesStore(paths: store.paths).load()
        XCTAssertEqual(prefs.theme, .mint)
        XCTAssertEqual(prefs.scope, .all)
        XCTAssertTrue(prefs.shuffle)
        XCTAssertTrue(prefs.starredOnly)
    }

    /// Saves a library holding one subject named `name` and returns its file bytes.
    private func saveLibrary(_ name: String) throws -> Data {
        var lib = Library()
        lib.addSubject(name: name)
        try store.save(lib)
        return try Data(contentsOf: store.paths.libraryURL)
    }

    private func minute(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + Double(n) * 60) }

    func testBackupSnapshotsEachChangedLaunch() throws {
        let a = try saveLibrary("A")
        try store.backup(at: minute(0))
        let b = try saveLibrary("B")
        try store.backup(at: minute(1))
        let snapshots = try store.backups()
        XCTAssertEqual(try snapshots.map { try Data(contentsOf: $0) }, [a, b])
    }

    func testBackupSkipsUnchangedLibrary() throws {
        _ = try saveLibrary("A")
        try store.backup(at: minute(0))
        try store.backup(at: minute(1))
        XCTAssertEqual(try store.backups().count, 1)
    }

    /// A mistake followed by many launches still leaves the 10 newest states; other files stay.
    func testBackupKeepsNewestTen() throws {
        try FileManager.default.createDirectory(at: store.paths.backupsFolder, withIntermediateDirectories: true)
        let notes = store.paths.backupsFolder.appendingPathComponent("notes.txt")
        try Data("mine".utf8).write(to: notes)
        var saved: [Data] = []
        for n in 0..<12 {
            saved.append(try saveLibrary("S\(n)"))
            try store.backup(at: minute(n))
        }
        let snapshots = try store.backups()
        XCTAssertEqual(snapshots.count, LibraryStore.keptBackups)
        XCTAssertEqual(try snapshots.map { try Data(contentsOf: $0) }, Array(saved.suffix(LibraryStore.keptBackups)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: notes.path))
    }

    func testBackupWithoutLibraryWritesNothing() throws {
        try store.backup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.paths.backupsFolder.path))
    }

    func testPreferencesPartialFileUsesDefaults() throws {
        try Data(#"{"theme":"purple"}"#.utf8).write(to: store.paths.preferencesURL)
        var expected = Preferences()
        expected.theme = .purple
        XCTAssertEqual(PreferencesStore(paths: store.paths).load(), expected)
    }
}
