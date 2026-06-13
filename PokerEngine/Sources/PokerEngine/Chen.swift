import Foundation

/// Chen formula: classic preflop starting-hand point system (AA = 20, AKs = 12).
public enum Chen {
    public static func score(_ hole: [Card]) -> Int {
        precondition(hole.count == 2)
        let sorted = hole.sorted { $0.rank > $1.rank }
        let a = sorted[0], b = sorted[1]
        let highPoints: [Int: Double] = [14: 10, 13: 8, 12: 7, 11: 6]
        var points = highPoints[a.rank] ?? Double(a.rank) / 2

        if a.rank == b.rank {
            return max(5, Int(points * 2))
        }
        if a.suit == b.suit { points += 2 }
        let gap = a.rank - b.rank - 1
        switch gap {
        case 0: break
        case 1: points -= 1
        case 2: points -= 2
        case 3: points -= 4
        default: points -= 5
        }
        if gap <= 1 && a.rank < 12 { points += 1 } // connected low cards make straights
        return Int(points.rounded(.up))
    }

    /// One step of the Chen formula, for teaching UIs that show the score
    /// being built.
    public struct Step: Sendable, Identifiable {
        public let label: String
        public let points: Double
        public var id: String { label }
    }

    /// The formula as visible steps. The steps sum to the pre-rounding
    /// total; `score` is that total rounded up (pairs floor at 5).
    public static func breakdown(_ hole: [Card]) -> [Step] {
        precondition(hole.count == 2)
        let sorted = hole.sorted { $0.rank > $1.rank }
        let a = sorted[0], b = sorted[1]
        let highPoints: [Int: Double] = [14: 10, 13: 8, 12: 7, 11: 6]
        let base = highPoints[a.rank] ?? Double(a.rank) / 2
        var steps = [Step(label: "\(Card.word(a.rank)) high card", points: base)]

        if a.rank == b.rank {
            steps.append(Step(label: "Pair — double it", points: base))
            if base * 2 < 5 {
                steps.append(Step(label: "Pair minimum (floor of 5)", points: 5 - base * 2))
            }
            return steps
        }
        if a.suit == b.suit {
            steps.append(Step(label: "Suited", points: 2))
        }
        let gap = a.rank - b.rank - 1
        switch gap {
        case 0: break
        case 1: steps.append(Step(label: "One-card gap", points: -1))
        case 2: steps.append(Step(label: "Two-card gap", points: -2))
        case 3: steps.append(Step(label: "Three-card gap", points: -4))
        default: steps.append(Step(label: "Wide gap", points: -5))
        }
        if gap <= 1 && a.rank < 12 {
            steps.append(Step(label: "Low connectors (straight potential)", points: 1))
        }
        return steps
    }

    public static func describe(_ hole: [Card]) -> String {
        let sorted = hole.sorted { $0.rank > $1.rank }
        let a = sorted[0], b = sorted[1]
        if a.rank == b.rank { return "a pair of \(Card.plural(a.rank))" }
        let suited = a.suit == b.suit ? "suited" : "offsuit"
        return "\(Card.word(a.rank))-\(Card.word(b.rank)) \(suited)"
    }
}
