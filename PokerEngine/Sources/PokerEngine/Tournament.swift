import Foundation

/// Sit-n-go schedule and payout maths. Pure value type — the engine handles
/// hands and eliminations; this owns the blind ladder and the prize split.
public struct TournamentState: Sendable, Equatable {
    public static let buyIn = 1000
    public static let startingStack = 1000      // 50 big blinds at level 1
    public static let handsPerLevel = 6          // standard pace
    public static let fieldSize = 4

    /// Escalating blind levels (small, big).
    public static let levels: [(sb: Int, bb: Int)] = [
        (10, 20), (15, 30), (25, 50), (40, 80), (60, 120),
        (100, 200), (150, 300), (250, 500), (400, 800), (600, 1200),
    ]

    /// Prize pool split: top two paid, 65 / 35.
    public static var pool: Int { buyIn * fieldSize }                 // 4000
    public static let payouts: [Int] = [ (4000 * 65) / 100, (4000 * 35) / 100 ]  // 2600, 1400

    public private(set) var levelIndex = 0
    public private(set) var handsThisLevel = 0

    public init() {}

    public var blinds: (sb: Int, bb: Int) { Self.levels[min(levelIndex, Self.levels.count - 1)] }
    public var level: Int { levelIndex + 1 }

    /// Call after each completed hand; advances the level on schedule.
    public mutating func handCompleted() {
        handsThisLevel += 1
        if handsThisLevel >= Self.handsPerLevel && levelIndex < Self.levels.count - 1 {
            levelIndex += 1
            handsThisLevel = 0
        }
    }

    /// Prize for a finishing place (0 = champion). 0 outside the money.
    public static func payout(place: Int) -> Int {
        place < payouts.count ? payouts[place] : 0
    }
}
