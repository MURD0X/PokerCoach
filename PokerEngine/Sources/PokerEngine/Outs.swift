import Foundation

public struct OutInfo: Identifiable, Sendable, Equatable {
    public let card: Card
    public let makes: HandCategory
    public var id: Int { card.id }
}

/// Outs: unseen cards that upgrade the player's hand to a better category,
/// where a hole card is part of what forms the new category (a card that
/// merely pairs the shared board improves everyone equally and doesn't count).
public enum Outs {
    public static func compute(hole: [Card], board: [Card]) -> [OutInfo] {
        guard board.count == 3 || board.count == 4 else { return [] }
        let currentCategory = HandEvaluator.category(of: HandEvaluator.bestScore(hole + board))
        let used = Set(hole + board)
        var outs: [OutInfo] = []

        for card in Deck.full() where !used.contains(card) {
            let improved = HandEvaluator.best(hole + board + [card])
            let newCategory = HandEvaluator.category(of: improved.score)
            guard newCategory > currentCategory else { continue }
            let core = coreCards(of: improved.hand, category: newCategory)
            if core.contains(where: { hole.contains($0) }) {
                outs.append(OutInfo(card: card, makes: newCategory))
            }
        }
        return outs.sorted {
            $0.makes != $1.makes ? $0.makes > $1.makes : $0.card.id > $1.card.id
        }
    }

    /// Rule of 4 and 2: rough equity boost from outs (×4 on the flop with two
    /// cards to come, ×2 on the turn).
    public static func ruleOfFourAndTwo(outCount: Int, boardCount: Int) -> Int {
        boardCount == 3 ? outCount * 4 : outCount * 2
    }

    // The cards that constitute the category itself — the pair, the trips,
    // the whole straight/flush — as opposed to kickers riding along.
    private static func coreCards(of hand: [Card], category: HandCategory) -> [Card] {
        switch category {
        case .straight, .flush, .straightFlush, .fullHouse:
            return hand
        case .highCard:
            return [hand.max { $0.rank < $1.rank }!]
        case .pair, .twoPair, .threeOfAKind, .fourOfAKind:
            var counts: [Int: Int] = [:]
            for c in hand { counts[c.rank, default: 0] += 1 }
            return hand.filter { counts[$0.rank]! >= 2 }
        }
    }
}
