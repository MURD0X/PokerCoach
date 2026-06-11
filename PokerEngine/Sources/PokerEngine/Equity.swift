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

/// Monte Carlo equity: deal random opponent hands and remaining board many
/// times and count wins and ties. Pure function — safe to run off the main
/// thread for the live stats dashboard.
public enum Equity {
    public static func estimate(hole: [Card], board: [Card], opponents: Int, trials: Int) -> EquityResult {
        precondition(hole.count == 2 && board.count <= 5 && opponents >= 1)
        var rng = SystemRandomNumberGenerator()
        let used = Set(hole + board)
        var stub = Deck.full().filter { !used.contains($0) }
        let need = opponents * 2 + (5 - board.count)
        var wins = 0.0
        var ties = 0.0

        for _ in 0..<trials {
            // Partial Fisher-Yates: only the first `need` cards matter per trial.
            for i in 0..<need {
                let j = Int.random(in: i..<stub.count, using: &rng)
                stub.swapAt(i, j)
            }
            var idx = 0
            var fullBoard = board
            while fullBoard.count < 5 {
                fullBoard.append(stub[idx])
                idx += 1
            }
            let heroScore = HandEvaluator.bestScore(hole + fullBoard)
            var beaten = false
            var tied = false
            for _ in 0..<opponents {
                let oppScore = HandEvaluator.bestScore([stub[idx], stub[idx + 1]] + fullBoard)
                idx += 2
                if oppScore > heroScore { beaten = true; break }
                if oppScore == heroScore { tied = true }
            }
            if !beaten {
                if tied { ties += 1 } else { wins += 1 }
            }
        }
        return EquityResult(win: wins / Double(trials), tie: ties / Double(trials))
    }
}
