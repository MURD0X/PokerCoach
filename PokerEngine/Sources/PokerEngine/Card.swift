import Foundation

public enum Suit: Int, CaseIterable, Codable, Hashable, Sendable {
    case spades = 0, hearts, diamonds, clubs

    public var symbol: String { ["♠", "♥", "♦", "♣"][rawValue] }
    public var isRed: Bool { self == .hearts || self == .diamonds }
}

public struct Card: Hashable, Codable, Identifiable, Sendable {
    public let rank: Int // 2...14, where 11=J, 12=Q, 13=K, 14=A
    public let suit: Suit

    public init(_ rank: Int, _ suit: Suit) {
        precondition((2...14).contains(rank), "rank out of range")
        self.rank = rank
        self.suit = suit
    }

    public var id: Int { rank * 4 + suit.rawValue }

    public var rankText: String {
        switch rank {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return String(rank)
        }
    }

    public var text: String { rankText + suit.symbol }

    static let rankWords: [Int: String] = [
        2: "Two", 3: "Three", 4: "Four", 5: "Five", 6: "Six", 7: "Seven", 8: "Eight",
        9: "Nine", 10: "Ten", 11: "Jack", 12: "Queen", 13: "King", 14: "Ace",
    ]
    static let rankPlurals: [Int: String] = [
        2: "Twos", 3: "Threes", 4: "Fours", 5: "Fives", 6: "Sixes", 7: "Sevens", 8: "Eights",
        9: "Nines", 10: "Tens", 11: "Jacks", 12: "Queens", 13: "Kings", 14: "Aces",
    ]

    public static func word(_ rank: Int) -> String { rankWords[rank] ?? String(rank) }
    public static func plural(_ rank: Int) -> String { rankPlurals[rank] ?? String(rank) }
}

public enum Deck {
    public static func full() -> [Card] {
        var cards: [Card] = []
        cards.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in 2...14 {
                cards.append(Card(rank, suit))
            }
        }
        return cards
    }

    /// A fresh deck shuffled with the system CSPRNG (`SystemRandomNumberGenerator`
    /// uses the OS cryptographic source on Apple platforms), so every permutation
    /// is equally likely and unpredictable — a fair deal every hand.
    public static func shuffled() -> [Card] {
        var rng = SystemRandomNumberGenerator()
        return full().shuffled(using: &rng)
    }
}
