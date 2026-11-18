import XCTest
@testable import flashCKCore

final class PendingWritesTests: XCTestCase {
    private var dir: URL!
    private var store: LibraryStore!
    private var prefsStore: PreferencesStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("flashCKTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = LibraryStore(paths: DataPaths(folder: dir))
        prefsStore = PreferencesStore(paths: store.paths)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func library(named name: String) -> Library {
        var lib = Library()
        lib.addSubject(name: name)
        return lib
    }

    /// A file at the backups folder path makes the backup write fail.
    private func blockBackup() throws {
        try Data("x".utf8).write(to: store.paths.backupsFolder)
    }

    private func newestBackup() throws -> Data {
        try Data(contentsOf: XCTUnwrap(store.backups().last))
    }

    func testBackupThenSaveWritesBoth() throws {
        try store.save(library(named: "Before"))
        let before = try Data(contentsOf: store.paths.libraryURL)
        var pending = PendingWrites(backup: true)
        pending.library = true
        pending.preferences = true
        let errors = pending.flush(library(named: "After"), Preferences(), libraryStore: store,
                                   preferencesStore: prefsStore)
        XCTAssertEqual(errors, [])
        XCTAssertEqual(pending, PendingWrites())
        XCTAssertEqual(try newestBackup(), before)
        XCTAssertEqual(try store.load()?.library.subjects.map(\.name), ["After"])
    }

    func testFailedBackupKeepsLibraryUnwrittenUntilRetrySucceeds() throws {
        try store.save(library(named: "Before"))
        let before = try Data(contentsOf: store.paths.libraryURL)
        try blockBackup()
        var pending = PendingWrites(backup: true)
        pending.library = true
        pending.preferences = true

        let errors = pending.flush(library(named: "After"), Preferences(), libraryStore: store,
                                   preferencesStore: prefsStore)
        XCTAssertEqual(errors.count, 2)
        XCTAssertTrue(pending.backup)
        XCTAssertTrue(pending.library)
        XCTAssertFalse(pending.preferences)
        XCTAssertEqual(try Data(contentsOf: store.paths.libraryURL), before)

        try FileManager.default.removeItem(at: store.paths.backupsFolder)
        XCTAssertEqual(pending.flush(library(named: "After"), Preferences(), libraryStore: store,
                                     preferencesStore: prefsStore), [])
        XCTAssertEqual(try newestBackup(), before)
        XCTAssertEqual(try store.load()?.library.subjects.map(\.name), ["After"])
    }

    func testFailedSaveStaysPending() throws {
        try FileManager.default.createDirectory(at: store.paths.libraryURL, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: store.paths.libraryURL.appendingPathComponent("keep"))
        var pending = PendingWrites()
        pending.library = true
        let errors = pending.flush(library(named: "A"), Preferences(), libraryStore: store,
                                   preferencesStore: prefsStore)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(pending.library)
    }
}
