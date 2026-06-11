import Foundation

public enum CoachAction: String, Sendable {
    case fold = "FOLD"
    case check = "CHECK"
    case call = "CALL"
    case bet = "BET"
    case raise = "RAISE"
}

public struct CoachAdvice: Sendable {
    public let action: CoachAction
    public let lines: [String]

    public init(action: CoachAction, lines: [String]) {
        self.action = action
        self.lines = lines
    }
}

public enum Coach {
    public static func preflopAdvice(hole: [Card], toCall: Int, bigBlind: Int) -> CoachAdvice {
        let score = Chen.score(hole)
        var lines = [
            "You hold \(Chen.describe(hole)).",
            "Starting-hand strength: \(score) points on the Chen scale (best hands score ~20, playable hands ~7+).",
        ]
        let action: CoachAction
        if score >= 10 {
            action = .raise
            lines.append("This is a premium hand. Raising builds the pot while you are likely ahead, and thins the field so fewer opponents can outdraw you.")
        } else if score >= 8 {
            action = toCall > 3 * bigBlind ? .call : .raise
            lines.append("A strong hand — play it aggressively, but be careful if someone re-raises big.")
        } else if score >= 6 {
            if toCall == 0 {
                action = .check
                lines.append("A playable hand. Since checking is free, see the flop and re-evaluate.")
            } else if toCall <= 2 * bigBlind {
                action = .call
                lines.append("A playable hand worth a cheap look at the flop — but not strong enough to raise or call big bets with.")
            } else {
                action = .fold
                lines.append("Playable, but not worth this much money before the flop. Folding marginal hands to big raises saves chips long-term.")
            }
        } else {
            if toCall == 0 {
                action = .check
                lines.append("A weak hand, but checking is free — take the flop and plan to fold to bets unless it improves a lot.")
            } else {
                action = .fold
                lines.append("A weak starting hand. Most beginner losses come from playing too many hands — folding here is the disciplined play.")
            }
        }
        return CoachAdvice(action: action, lines: lines)
    }

    public static func postflopAdvice(
        hole: [Card], board: [Card], equity: EquityResult,
        toCall: Int, pot: Int, opponents: Int, outs: [OutInfo]
    ) -> CoachAdvice {
        let eq = equity.decisionEquity
        let eqPct = Int((eq * 100).rounded())
        let madeName = HandEvaluator.name(of: HandEvaluator.bestScore(hole + board))
        var lines = ["Your best hand right now: \(madeName)."]

        if !outs.isEmpty && board.count < 5 {
            let estimate = Outs.ruleOfFourAndTwo(outCount: outs.count, boardCount: board.count)
            lines.append("You have \(outs.count) outs — cards that improve your hand (≈\(min(estimate, 95))% to hit by the river using the rule of \(board.count == 3 ? "4" : "2")).")
        }
        lines.append("Win probability: ~\(eqPct)% against \(opponents) opponent\(opponents > 1 ? "s" : "") (Monte Carlo simulation).")

        let action: CoachAction
        if toCall > 0 {
            let potOdds = Double(toCall) / Double(pot + toCall)
            let poPct = Int((potOdds * 100).rounded())
            lines.append("Pot odds: call \(toCall) to win a \(pot + toCall) pot — you need better than \(poPct)% to profit.")
            if eq > potOdds + 0.2 && eq > 0.5 {
                action = .raise
                lines.append("Your \(eqPct)% is far above the \(poPct)% you need. Raise for value — make weaker hands pay to continue.")
            } else if eq > potOdds {
                action = .call
                lines.append("\(eqPct)% beats the \(poPct)% you need, so calling is profitable — but you're not strong enough to raise.")
            } else {
                action = .fold
                lines.append("\(eqPct)% is below the \(poPct)% required. Calling loses money on average — fold and wait for a better spot.")
            }
        } else {
            if eq > 0.65 {
                action = .bet
                lines.append("You are a clear favorite. Bet for value — checking lets opponents see free cards that could beat you.")
            } else if eq > 0.45 && opponents == 1 {
                action = .bet
                lines.append("Against a single opponent you figure to be ahead. A bet can win the pot right now or charge their draws.")
            } else {
                action = .check
                lines.append("Your hand is not strong enough to bet for value. Check and see a free card.")
            }
        }
        return CoachAdvice(action: action, lines: lines)
    }
}
