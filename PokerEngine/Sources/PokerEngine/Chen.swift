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

    public static func describe(_ hole: [Card]) -> String {
        let sorted = hole.sorted { $0.rank > $1.rank }
        let a = sorted[0], b = sorted[1]
        if a.rank == b.rank { return "a pair of \(Card.plural(a.rank))" }
        let suited = a.suit == b.suit ? "suited" : "offsuit"
        return "\(Card.word(a.rank))-\(Card.word(b.rank)) \(suited)"
    }
}
