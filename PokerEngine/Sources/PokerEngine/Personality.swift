import Foundation

/// Three-axis opponent personality, rolled randomly per opponent:
/// - `tightness`: 0 = plays almost anything, 1 = waits for premium hands
/// - `aggression`: 0 = checks and calls, 1 = bets and raises relentlessly
/// - `skill`: 0 = ignores pot odds and misjudges strength, 1 = plays the math
public struct Personality: Sendable, Equatable, Codable {
    public let tightness: Double
    public let aggression: Double
    public let skill: Double

    public init(tightness: Double, aggression: Double, skill: Double) {
        self.tightness = min(1, max(0, tightness))
        self.aggression = min(1, max(0, aggression))
        self.skill = min(1, max(0, skill))
    }

    public static func random() -> Personality {
        var rng = SystemRandomNumberGenerator()
        return Personality(
            tightness: Double.random(in: 0...1, using: &rng),
            aggression: Double.random(in: 0...1, using: &rng),
            skill: Double.random(in: 0...1, using: &rng)
        )
    }

    /// Neutral profile (used when a player has no personality, e.g. tests).
    public static let balanced = Personality(tightness: 0.5, aggression: 0.5, skill: 0.5)

    // Trait labels use standard poker vocabulary so reading opponents in the
    // app teaches terms that transfer to real tables.
    public var tightnessLabel: String {
        tightness >= 0.6 ? "Tight" : (tightness <= 0.4 ? "Loose" : "Balanced")
    }
    public var aggressionLabel: String {
        aggression >= 0.6 ? "Aggressive" : (aggression <= 0.4 ? "Passive" : "Measured")
    }
    public var skillLabel: String {
        skill >= 0.7 ? "Expert" : (skill >= 0.35 ? "Solid" : "Rookie")
    }

    public var styleName: String {
        "\(tightnessLabel) · \(aggressionLabel) · \(skillLabel)"
    }

    // MARK: - Decision parameters (pure functions of the three axes)

    /// Minimum Chen score this player open-raises with (8…11).
    public var preflopRaiseThreshold: Double { 8 + tightness * 3 }
    /// Minimum Chen score this player calls a normal raise with (4…7).
    public var preflopCallThreshold: Double { 4 + tightness * 3 }
    /// Chance to limp in with junk anyway (25% for the loosest, 0% for the tightest).
    public var speculativeCallRate: Double { (1 - tightness) * 0.25 }
    /// Chance to bluff or semi-bluff when checked to (2%…16%).
    public var bluffRate: Double { 0.02 + aggression * 0.14 }
    /// Equity needed to value-bet (aggressive players bet thinner: 0.52…0.68).
    public var valueBetThreshold: Double { 0.68 - aggression * 0.16 }
    /// Chance to raise (rather than call) with a strong hand (30%…80%).
    public var raiseWithStrengthRate: Double { 0.3 + aggression * 0.5 }
    /// How honestly they price calls: 1.0 = perfect pot-odds discipline,
    /// lower = calls too much (the classic calling-station leak).
    public var potOddsDiscipline: Double { 0.45 + skill * 0.55 }
    /// Magnitude of equity misjudgment (±18% for a rookie, ±0 for an expert).
    public var equityNoise: Double { (1 - skill) * 0.18 }
    /// Monte Carlo trials this player "thinks" with (60…180).
    public var equityTrials: Int { 60 + Int(skill * 120) }
}

/// Random opponent lineups for a fresh table.
public enum OpponentFactory {
    static let names = [
        "Maya", "Dmitri", "Rosa", "Felix", "Anika", "Jorge", "Wei", "Sasha",
        "Priya", "Marco", "Yuki", "Omar", "Elena", "Kofi", "Astrid", "Theo",
        "Ines", "Ravi", "Greta", "Nico", "Aisha", "Bruno", "Carmen", "Dara",
        "Emeka", "Freya", "Goran", "Hana", "Idris", "Jules", "Kira", "Luca",
        "Mei", "Nadia", "Oscar", "Paulo", "Quinn", "Rina", "Stefan", "Tara",
        "Umar", "Vera", "Wren", "Ximena", "Yara", "Zane", "Bea", "Cyrus",
        "Dalia", "Enzo", "Farah", "Gus", "Hilde", "Ivo", "Jana", "Kenji",
        "Lola", "Milos", "Noor", "Petra",
    ]

    /// Draw `count` distinct opponents, never reusing a name in `excluding` —
    /// so a re-rolled table always feels like new players sat down.
    public static func randomLineup(count: Int, excluding: Set<String> = []) -> [(name: String, personality: Personality)] {
        var rng = SystemRandomNumberGenerator()
        let pool = names.filter { !excluding.contains($0) }
        return Array(pool.shuffled(using: &rng).prefix(count)).map { ($0, Personality.random()) }
    }
}
