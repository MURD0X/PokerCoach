import Foundation

public enum HandCategory: Int, Comparable, CaseIterable, Sendable {
    case highCard = 0, pair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush

    public static func < (lhs: HandCategory, rhs: HandCategory) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .highCard: return "High Card"
        case .pair: return "Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        }
    }
}

/// Scores 5-card hands as a single integer; higher beats lower. The category
/// occupies the high digits and up to five tiebreaker ranks (base 15) sit
/// below it, so any two hands compare with plain `>`.
public enum HandEvaluator {
    static let base = 759_375 // 15^5

    public static func evaluate5(_ cards: [Card]) -> Int {
        let ranks = cards.map(\.rank).sorted(by: >)
        let isFlush = cards.allSatisfy { $0.suit == cards[0].suit }

        var straightHigh = 0
        let uniq = Set(ranks).sorted(by: >)
        if uniq.count == 5 {
            if uniq[0] - uniq[4] == 4 {
                straightHigh = uniq[0]
            } else if uniq[0] == 14 && uniq[1] == 5 {
                straightHigh = 5 // A-2-3-4-5 wheel
            }
        }

        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        let groups = counts
            .map { (count: $0.value, rank: $0.key) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.rank > $1.rank }

        let cat: HandCategory
        var tie: [Int]
        if straightHigh > 0 && isFlush {
            cat = .straightFlush; tie = [straightHigh]
        } else if groups[0].count == 4 {
            cat = .fourOfAKind; tie = [groups[0].rank, groups[1].rank]
        } else if groups[0].count == 3 && groups[1].count == 2 {
            cat = .fullHouse; tie = [groups[0].rank, groups[1].rank]
        } else if isFlush {
            cat = .flush; tie = ranks
        } else if straightHigh > 0 {
            cat = .straight; tie = [straightHigh]
        } else if groups[0].count == 3 {
            cat = .threeOfAKind; tie = [groups[0].rank, groups[1].rank, groups[2].rank]
        } else if groups[0].count == 2 && groups[1].count == 2 {
            cat = .twoPair; tie = [groups[0].rank, groups[1].rank, groups[2].rank]
        } else if groups[0].count == 2 {
            cat = .pair; tie = [groups[0].rank, groups[1].rank, groups[2].rank, groups[3].rank]
        } else {
            cat = .highCard; tie = ranks
        }

        var score = cat.rawValue
        for i in 0..<5 { score = score * 15 + (i < tie.count ? tie[i] : 0) }
        return score
    }

    /// Best 5-card score from 5, 6, or 7 cards.
    public static func bestScore(_ cards: [Card]) -> Int {
        best(cards).score
    }

    /// Best score plus the winning 5 cards (used to check whether an
    /// improvement actually involves the player's hole cards).
    public static func best(_ cards: [Card]) -> (score: Int, hand: [Card]) {
        if cards.count == 5 { return (evaluate5(cards), cards) }
        var bestScore = -1
        var bestHand: [Card] = []
        let n = cards.count
        if n == 6 {
            for skip in 0..<6 {
                var hand = cards
                hand.remove(at: skip)
                let s = evaluate5(hand)
                if s > bestScore { bestScore = s; bestHand = hand }
            }
        } else {
            for a in 0..<n {
                for b in (a + 1)..<n {
                    var hand: [Card] = []
                    hand.reserveCapacity(5)
                    for i in 0..<n where i != a && i != b { hand.append(cards[i]) }
                    let s = evaluate5(hand)
                    if s > bestScore { bestScore = s; bestHand = hand }
                }
            }
        }
        return (bestScore, bestHand)
    }

    public static func category(of score: Int) -> HandCategory {
        HandCategory(rawValue: score / base)!
    }

    public static func name(of score: Int) -> String {
        let cat = category(of: score)
        var rest = score - cat.rawValue * base
        var tie = [Int](repeating: 0, count: 5)
        for i in stride(from: 4, through: 0, by: -1) {
            tie[i] = rest % 15
            rest /= 15
        }
        switch cat {
        case .straightFlush:
            return tie[0] == 14 ? "Royal Flush" : "\(Card.word(tie[0]))-high Straight Flush"
        case .fourOfAKind: return "Four \(Card.plural(tie[0]))"
        case .fullHouse: return "Full House, \(Card.plural(tie[0])) over \(Card.plural(tie[1]))"
        case .flush: return "\(Card.word(tie[0]))-high Flush"
        case .straight: return "\(Card.word(tie[0]))-high Straight"
        case .threeOfAKind: return "Three \(Card.plural(tie[0]))"
        case .twoPair: return "Two Pair, \(Card.plural(tie[0])) and \(Card.plural(tie[1]))"
        case .pair: return "Pair of \(Card.plural(tie[0]))"
        case .highCard: return "\(Card.word(tie[0])) High"
        }
    }
}
