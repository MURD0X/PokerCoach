import Foundation

/// One training flashcard: a situation, and the coach's answer with its
/// reasoning. The user's pick is graded by Reviewer — same verdicts as the
/// post-hand review, so drills and real play teach the same standards.
public struct DrillSpot: Sendable {
    public let hole: [Card]
    public let board: [Card]
    public let position: Position
    public let pot: Int
    public let toCall: Int
    public let opponents: Int
    public let advice: CoachAdvice

    public var isPreflop: Bool { board.isEmpty }
    public var street: Stage {
        switch board.count {
        case 0: return .preflop
        case 3: return .flop
        case 4: return .turn
        default: return .river
        }
    }
}

/// Generates randomized, internally-consistent drill spots.
public enum DrillGenerator {
    public static func spot(stakes: TableStakes = .standard) -> DrillSpot {
        Bool.random() ? preflopSpot(stakes: stakes) : postflopSpot(stakes: stakes)
    }

    public static func preflopSpot(stakes: TableStakes = .standard) -> DrillSpot {
        var deck = Deck.shuffled()
        let hole = [deck.removeLast(), deck.removeLast()]
        let position = Position.allCases.randomElement()!
        let bb = stakes.bigBlind

        // Facing: an unopened pot, a standard raise, or a big raise.
        let (toCall, pot): (Int, Int)
        switch Int.random(in: 0..<3) {
        case 0:  // folded to you — just the blinds out there
            (toCall, pot) = (position == .bigBlind ? 0 : bb, stakes.smallBlind + bb)
        case 1:  // standard open in front of you
            (toCall, pot) = (3 * bb, stakes.smallBlind + bb + 3 * bb)
        default: // big raise in front of you
            (toCall, pot) = (5 * bb, stakes.smallBlind + bb + 5 * bb)
        }

        let advice = Coach.preflopAdvice(hole: hole, toCall: toCall, bigBlind: bb, position: position)
        return DrillSpot(hole: hole, board: [], position: position,
                         pot: pot, toCall: toCall, opponents: Int.random(in: 1...3), advice: advice)
    }

    public static func postflopSpot(stakes: TableStakes = .standard) -> DrillSpot {
        var deck = Deck.shuffled()
        let hole = [deck.removeLast(), deck.removeLast()]
        let boardCount = [3, 3, 4, 5].randomElement()! // flop-weighted
        let board = (0..<boardCount).map { _ in deck.removeLast() }
        let opponents = Int.random(in: 1...2)
        let bb = stakes.bigBlind

        let pot = bb * Int.random(in: 3...20)
        // Checked to you, or facing a bet between a third and full pot.
        let toCall = Bool.random() ? 0 : max(bb, (pot * Int.random(in: 1...3) / 3) / 10 * 10)

        let equity = Equity.estimate(hole: hole, board: board, opponents: opponents, trials: 1500)
        let outs = Outs.compute(hole: hole, board: board)
        let advice = Coach.postflopAdvice(
            hole: hole, board: board, equity: equity,
            toCall: toCall, pot: pot, opponents: opponents, outs: outs
        )
        return DrillSpot(hole: hole, board: board, position: Position.allCases.randomElement()!,
                         pot: pot, toCall: toCall, opponents: opponents, advice: advice)
    }
}
