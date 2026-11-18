import Foundation

/// Browse cards one at a time; next/previous wrap.
public struct CardsSession: Equatable, Sendable {
    public private(set) var order: [UUID]
    public private(set) var index = 0
    public var flipped = false
    public let shuffled: Bool

    public init(cardIDs: [UUID], shuffled: Bool, using rng: inout some RandomNumberGenerator) {
        order = shuffled ? cardIDs.shuffled(using: &rng) : cardIDs
        self.shuffled = shuffled
    }

    public init(cardIDs: [UUID], shuffled: Bool) {
        var rng = SystemRandomNumberGenerator()
        self.init(cardIDs: cardIDs, shuffled: shuffled, using: &rng)
    }

    public var count: Int { order.count }
    public var current: UUID? { order.isEmpty ? nil : order[index] }
    /// Previous / Next only move with two or more cards.
    public var canStep: Bool { order.count > 1 }

    /// Follows the study cards after some left or their order changed (a rename or move re-sorts them),
    /// keeping the place: the current card stays current, else the next card still there takes over
    /// (wrapping). Unshuffled sessions take the new order; shuffled ones keep theirs. `ids` adds no cards.
    /// The card face resets only when the current card goes.
    public mutating func update(to ids: [UUID]) {
        let kept = Set(ids)
        let anchor = (order[index...] + order[..<index]).first(where: kept.contains)
        if let current, !kept.contains(current) { flipped = false }
        order = shuffled ? order.filter(kept.contains) : ids
        index = anchor.flatMap { order.firstIndex(of: $0) } ?? 0
    }

    public mutating func next() { step(1) }
    public mutating func previous() { step(-1) }

    private mutating func step(_ delta: Int) {
        guard canStep else { return }
        index = (index + delta + order.count) % order.count
        flipped = false
    }
}
