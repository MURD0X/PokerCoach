import Foundation

public struct EquityResult: Sendable, Equatable {
    public let win: Double
    public let tie: Double

    public init(win: Double, tie: Double) {
        self.win = win
        self.tie = tie
    }

    /// Single number for decision-making: ties counted as half a win.
    public var decisionEquity: Double { win + tie / 2 }

    public static let zero = EquityResult(win: 0, tie: 0)
}

/// A constraint on what an opponent can plausibly hold, derived from their
/// public actions. `minChen` filters sampled hole cards to at least that
/// starting-hand strength; nil means any two cards.
public struct RangeConstraint: Sendable, Equatable {
    public let minChen: Int?

    public init(minChen: Int?) {
        self.minChen = minChen
    }

    public static let any = RangeConstraint(minChen: nil)
}

/// Monte Carlo equity: deal opponent hands and the remaining board many
/// times and count wins and ties. Opponent hands honor range constraints
/// via rejection sampling, with a bluff allowance so no holding is ever
/// truly impossible. Pure function — safe off the main thread.
public enum Equity {
    /// Fraction of constrained samples allowed to ignore the constraint —
    /// players limp monsters and raise junk sometimes.
    static let bluffAllowance = 0.12
    static let maxRejectionAttempts = 24

    public static func estimate(
        hole: [Card], board: [Card], opponents: Int, trials: Int,
        constraints: [RangeConstraint]? = nil
    ) -> EquityResult {
        precondition(hole.count == 2 && board.count <= 5 && opponents >= 1)
        precondition(constraints == nil || constraints!.count == opponents)
        var rng = SystemRandomNumberGenerator()
        let used = Set(hole + board)
        var stub = Deck.full().filter { !used.contains($0) }
        var wins = 0.0
        var ties = 0.0

        for _ in 0..<trials {
            var cursor = 0
            // Board first.
            var fullBoard = board
            while fullBoard.count < 5 {
                let j = Int.random(in: cursor..<stub.count, using: &rng)
                stub.swapAt(cursor, j)
                fullBoard.append(stub[cursor])
                cursor += 1
            }
            let heroScore = HandEvaluator.bestScore(hole + fullBoard)

            var beaten = false
            var tied = false
            for o in 0..<opponents {
                let constraint = constraints?[o] ?? .any
                drawHand(into: &stub, cursor: &cursor, constraint: constraint, using: &rng)
                let oppScore = HandEvaluator.bestScore([stub[cursor - 2], stub[cursor - 1]] + fullBoard)
                if oppScore > heroScore { beaten = true; break }
                if oppScore == heroScore { tied = true }
            }
            if !beaten {
                if tied { ties += 1 } else { wins += 1 }
            }
        }
        return EquityResult(win: wins / Double(trials), tie: ties / Double(trials))
    }

    // Draws two cards to positions cursor and cursor+1, rejection-sampling
    // until the pair meets the constraint (or attempts/bluff-allowance say
    // accept anyway). Swaps are reverted on rejection so the pool stays fair.
    private static func drawHand(
        into stub: inout [Card], cursor: inout Int,
        constraint: RangeConstraint, using rng: inout SystemRandomNumberGenerator
    ) {
        let allowBluff = constraint.minChen == nil
            || Double.random(in: 0..<1, using: &rng) < bluffAllowance

        for attempt in 0..<maxRejectionAttempts {
            let j1 = Int.random(in: cursor..<stub.count, using: &rng)
            stub.swapAt(cursor, j1)
            let j2 = Int.random(in: (cursor + 1)..<stub.count, using: &rng)
            stub.swapAt(cursor + 1, j2)

            let accepted: Bool
            if let floor = constraint.minChen, !allowBluff,
               attempt < maxRejectionAttempts - 1 {
                accepted = Chen.score([stub[cursor], stub[cursor + 1]]) >= floor
            } else {
                accepted = true
            }
            if accepted {
                cursor += 2
                return
            }
            // Revert in reverse order so the pool is exactly as before.
            stub.swapAt(cursor + 1, j2)
            stub.swapAt(cursor, j1)
        }
    }
}
