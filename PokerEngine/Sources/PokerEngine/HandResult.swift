import Foundation

/// Structured outcome of a completed hand, built by the engine so the UI can
/// show exactly who won, with what, and why it beat the other hands.
public struct HandResult: Sendable {
    public struct PlayerShowdown: Identifiable, Sendable {
        public let playerID: Int
        public let name: String
        public let hole: [Card]
        public let handName: String
        public let score: Int
        public let bestFive: [Card]
        public let amountWon: Int
        public var id: Int { playerID }
        public var isWinner: Bool { amountWon > 0 }
    }

    public let potTotal: Int
    /// Empty when the hand was won because everyone else folded.
    public let showdowns: [PlayerShowdown]
    public let winnerNames: [String]
    /// e.g. "Maya wins 240 with a Flush" or "Rosa wins 60 — everyone else folded"
    public let headline: String
    /// e.g. "Ace-high Flush beats Two Pair, Kings and Nines" — nil for fold wins.
    public let explanation: String?
    /// Cards to highlight on the table: the winning five (board + hole portions).
    public let winningCards: Set<Card>

    public var wonByFolds: Bool { showdowns.isEmpty }

    /// One line explaining why the winning hand beats the best losing hand.
    static func comparisonLine(winnerScore: Int, loserScore: Int) -> String {
        "\(HandEvaluator.name(of: winnerScore)) beats \(HandEvaluator.name(of: loserScore))"
    }
}
