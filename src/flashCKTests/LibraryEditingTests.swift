import XCTest
@testable import flashCKCore

final class LibraryEditingTests: XCTestCase {
    func testDeleteSubjectDeletesItsLessonsAndCards() throws {
        var lib = Library()
        let subject = lib.addSubject(name: "F"), other = lib.addSubject(name: "G")
        let lesson = try XCTUnwrap(lib.addLesson(name: "L", subjectID: subject))
        let kept = try XCTUnwrap(lib.addLesson(name: "K", subjectID: other))
        lib.addCard(to: lesson)
        lib.addCard(to: kept)
        lib.deleteSubject(subject)
        XCTAssertEqual(lib.subjects.map(\.id), [other])
        XCTAssertEqual(lib.lessons.map(\.id), [kept])
        XCTAssertEqual(lib.cardCount(for: .all), 1)
    }

    func testAddLessonNeedsAnExistingSubject() {
        var lib = Library()
        XCTAssertNil(lib.addLesson(name: "L", subjectID: UUID()))
        XCTAssertTrue(lib.lessons.isEmpty)
    }

    func testMoveLessonIgnoresMissingSubject() throws {
        var lib = Library()
        let subject = lib.addSubject(name: "F")
        let lesson = try XCTUnwrap(lib.addLesson(name: "L", subjectID: subject))
        lib.moveLesson(lesson, to: UUID())
        XCTAssertEqual(lib.lesson(id: lesson)?.subjectID, subject)
    }

    func testNormalizedSelectsFirstSubjectInsteadOfAll() throws {
        var lib = Library()
        var prefs = Preferences()
        XCTAssertEqual(prefs.normalized(for: lib).scope, .all)
        let z = lib.addSubject(name: "Z"), b = lib.addSubject(name: "B")
        XCTAssertEqual(prefs.normalized(for: lib).scope, .subject(b))
        prefs.scope = .subject(UUID())
        XCTAssertEqual(prefs.normalized(for: lib).scope, .subject(b))
        prefs.scope = .subject(z)
        XCTAssertEqual(prefs.normalized(for: lib).scope, .subject(z))
    }

    func testIsBlankIgnoresWhitespace() {
        XCTAssertTrue(Card(front: " \n", back: "").isBlank)
        XCTAssertFalse(Card(front: "", back: "b").isBlank)
    }

    func testLessonIDOfCard() throws {
        var lib = Library()
        let lesson = try XCTUnwrap(lib.addLesson(name: "L", subjectID: lib.addSubject(name: "S")))
        let card = try XCTUnwrap(lib.addCard(to: lesson))
        XCTAssertEqual(lib.lessonID(ofCard: card), lesson)
        XCTAssertNil(lib.lessonID(ofCard: UUID()))
    }

    func testCardsUseSidebarOrder() throws {
        var lib = Library()
        // Created out of order; sidebar order is subject B (lesson a), then subject Z (lessons x, y).
        let subjectZ = lib.addSubject(name: "Z"), subjectB = lib.addSubject(name: "B")
        let y = try XCTUnwrap(lib.addLesson(name: "y", subjectID: subjectZ))
        let x = try XCTUnwrap(lib.addLesson(name: "x", subjectID: subjectZ))
        let a = try XCTUnwrap(lib.addLesson(name: "a", subjectID: subjectB))
        let y1 = try XCTUnwrap(lib.addCard(to: y))
        let x1 = try XCTUnwrap(lib.addCard(to: x))
        let a1 = try XCTUnwrap(lib.addCard(to: a))
        let a2 = try XCTUnwrap(lib.addCard(to: a))

        XCTAssertEqual(lib.cards(for: .all).map(\.id), [a1, a2, x1, y1])
        XCTAssertEqual(lib.cards(for: .subject(subjectB)).map(\.id), [a1, a2])
    }

    func testDeleteRestorePutsCardBackAtSameIndex() throws {
        var lib = Library()
        let subject = lib.addSubject(name: "F")
        let lesson = try XCTUnwrap(lib.addLesson(name: "L", subjectID: subject))
        let ids = (0..<3).compactMap { _ in lib.addCard(to: lesson) }
        let deleted = try XCTUnwrap(lib.deleteCard(id: ids[1]))
        XCTAssertEqual(lib.lesson(id: lesson)?.cards.map(\.id), [ids[0], ids[2]])
        lib.restore(deleted)
        XCTAssertEqual(lib.lesson(id: lesson)?.cards.map(\.id), ids)
    }
}
