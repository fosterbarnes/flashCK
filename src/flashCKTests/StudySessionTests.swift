import XCTest
@testable import flashCKCore

/// Deterministic RNG so shuffles are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class StudySessionTests: XCTestCase {
    func testCardsShuffleIsPermutation() {
        let ids = (0..<20).map { _ in UUID() }
        var rng = SplitMix64(seed: 42)
        var s = CardsSession(cardIDs: ids, shuffled: true, using: &rng)
        XCTAssertEqual(Set(s.order), Set(ids))
        XCTAssertEqual(s.count, ids.count)
        XCTAssertNotEqual(s.order, ids)
        s.previous()
        XCTAssertEqual(s.index, ids.count - 1)
        s.next()
        XCTAssertEqual(s.index, 0)
    }

    /// Unstarring under `starredOnly` removes cards mid-session; studying goes on from the same place.
    func testRemovalKeepsPlace() {
        let ids = (0..<5).map { _ in UUID() }
        var s = CardsSession(cardIDs: ids, shuffled: false)
        s.next(); s.next()
        s.flipped = true
        s.update(to: Array(ids[1...]))
        XCTAssertEqual(s.current, ids[2])
        XCTAssertTrue(s.flipped)
        s.update(to: [ids[1], ids[3], ids[4]])
        XCTAssertEqual(s.current, ids[3])
        XCTAssertFalse(s.flipped)
        s.next()
        s.update(to: [ids[1], ids[3]])
        XCTAssertEqual(s.current, ids[1])
        s.update(to: [])
        XCTAssertNil(s.current)
        XCTAssertEqual(s.index, 0)
    }

    /// Renaming a lesson re-sorts the cards; an unshuffled session follows the new order from the same card.
    func testReorderKeepsPlaceInNewOrder() {
        let ids = (0..<4).map { _ in UUID() }
        var s = CardsSession(cardIDs: ids, shuffled: false)
        s.next(); s.next()
        s.flipped = true
        s.update(to: [ids[2], ids[3], ids[0], ids[1]])
        XCTAssertEqual(s.current, ids[2])
        XCTAssertEqual(s.index, 0)
        XCTAssertTrue(s.flipped)
        XCTAssertEqual(s.order, [ids[2], ids[3], ids[0], ids[1]])
    }

    func testReorderKeepsShuffledOrder() {
        let ids = (0..<10).map { _ in UUID() }
        var rng = SplitMix64(seed: 7)
        var s = CardsSession(cardIDs: ids, shuffled: true, using: &rng)
        s.next(); s.next()
        s.flipped = true
        let (order, current) = (s.order, s.current)
        s.update(to: ids.reversed())
        XCTAssertEqual(s.order, order)
        XCTAssertEqual(s.current, current)
        XCTAssertTrue(s.flipped)
    }

    /// The current card goes and the rest re-sort: the next card in the old order takes over.
    func testRemovalWithReorder() {
        let ids = (0..<4).map { _ in UUID() }
        var s = CardsSession(cardIDs: ids, shuffled: false)
        s.next()
        s.flipped = true
        s.update(to: [ids[3], ids[2], ids[0]])
        XCTAssertEqual(s.current, ids[2])
        XCTAssertEqual(s.index, 1)
        XCTAssertFalse(s.flipped)
    }

    func testSingleCardDoesNotStep() {
        var s = CardsSession(cardIDs: [UUID()], shuffled: false)
        XCTAssertFalse(s.canStep)
        s.flipped = true
        s.next()
        s.previous()
        XCTAssertEqual(s.index, 0)
        XCTAssertTrue(s.flipped)
        XCTAssertFalse(CardsSession(cardIDs: [], shuffled: false).canStep)
        XCTAssertTrue(CardsSession(cardIDs: [UUID(), UUID()], shuffled: false).canStep)
    }
}
