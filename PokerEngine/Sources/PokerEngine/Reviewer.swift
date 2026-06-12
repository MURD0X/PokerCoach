import Foundation

/// Grades one hero decision after the fact, using only what was knowable at
/// the moment — the same numbers the coach had, never the opponents' cards.
public enum ReviewVerdict: Int, Sendable, Comparable {
    case followed = 0    // matched the coach
    case acceptable = 1  // deviated, but defensibly
    case leak = 2        // the kind of decision that loses chips long-term

    public static func < (lhs: ReviewVerdict, rhs: ReviewVerdict) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct DecisionReview: Sendable {
    public let verdict: ReviewVerdict
    public let line: String
    /// How bad a leak is (equity shortfall × pot share); 0 unless a leak.
    public let severity: Double
}

public enum Reviewer {
    /// The action families the adherence stat already uses.
    static func family(_ action: HeroAction) -> CoachAction {
        switch action {
        case .fold: return .fold
        case .checkCall: return .call
        case .raise: return .raise
        }
    }

    static func sameFamily(_ rec: CoachAction, _ action: HeroAction) -> Bool {
        switch (rec, family(action)) {
        case (.fold, .fold): return true
        case (.check, .call), (.call, .call): return true
        case (.bet, .raise), (.raise, .raise): return true
        default: return false
        }
    }

    public static func review(
        recommendation: CoachAction, action: HeroAction,
        equity: Double?, potOddsNeeded: Double?, street: Stage
    ) -> DecisionReview {
        let eqPct = equity.map { Int(($0 * 100).rounded()) }
        let needPct = potOddsNeeded.map { Int(($0 * 100).rounded()) }

        if sameFamily(recommendation, action) {
            var line = "Matched the coach."
            if let e = eqPct, let n = needPct {
                line = "Matched the coach — \(e)% equity against \(n)% needed."
            } else if let e = eqPct {
                line = "Matched the coach with \(e)% equity."
            }
            return DecisionReview(verdict: .followed, line: line, severity: 0)
        }

        // Deviations, graded by the math when we have it.
        switch (recommendation, family(action)) {
        case (.fold, .call), (.fold, .raise):
            if let e = equity, let n = potOddsNeeded, e < n {
                let severity = (n - e)
                return DecisionReview(
                    verdict: .leak,
                    line: "Put chips in with \(eqPct!)% needing \(needPct!)% — this is the call that costs money long-term.",
                    severity: severity
                )
            }
            return DecisionReview(verdict: .acceptable,
                line: "Looser than the coach here — playable, but know why you're doing it.", severity: 0)

        case (.call, .fold), (.check, .fold), (.bet, .fold), (.raise, .fold):
            if let e = eqPct, let n = needPct {
                return DecisionReview(verdict: .leak,
                    line: "Folded \(e)% equity when \(n)% was the price — surrendered a profitable spot.",
                    severity: max(0, (equity ?? 0) - (potOddsNeeded ?? 0)))
            }
            return DecisionReview(verdict: .acceptable,
                line: "Tighter than the coach — folding a playable hand is rarely a disaster.", severity: 0)

        case (.call, .raise), (.check, .raise):
            return DecisionReview(verdict: .acceptable,
                line: "More aggressive than the coach\(eqPct.map { " with \($0)% equity" } ?? "") — a defensible line.",
                severity: 0)

        case (.bet, .call), (.raise, .call):
            return DecisionReview(verdict: .acceptable,
                line: "More passive than the coach — you kept the pot small where a bet had value.", severity: 0)

        default:
            return DecisionReview(verdict: .acceptable, line: "A different line than the coach's.", severity: 0)
        }
    }
}
