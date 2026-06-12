import Foundation

/// A table's blind structure. Buy-in is the standard 50 big blinds.
public struct TableStakes: Sendable, Equatable, Hashable, Identifiable, Codable {
    public let smallBlind: Int
    public let bigBlind: Int

    public init(smallBlind: Int, bigBlind: Int) {
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
    }

    public var buyIn: Int { bigBlind * 50 }
    public var name: String { "\(smallBlind)/\(bigBlind)" }
    public var id: Int { bigBlind }

    public static let low = TableStakes(smallBlind: 5, bigBlind: 10)
    public static let standard = TableStakes(smallBlind: 10, bigBlind: 20)
    public static let high = TableStakes(smallBlind: 25, bigBlind: 50)
    public static let all: [TableStakes] = [.low, .standard, .high]

    /// Bankroll-management guidance: fraction of the bankroll this table's
    /// buy-in consumes. The classic guideline is to stay under ~10%.
    public func bankrollFraction(of balance: Int) -> Double {
        guard balance > 0 else { return 1 }
        return Double(buyIn) / Double(balance)
    }
}

/// The money behind the table money. Pure value type — persistence is the
/// app layer's job. All flows go through here so the math is testable:
/// sitting down costs a buy-in, leaving returns the stack, busting returns
/// nothing, and ruin (can't afford a seat) resets to a fresh bankroll.
public struct BankrollLedger: Sendable, Equatable {
    public static let startingAmount = 10_000
    public static let buyIn = 1_000

    public private(set) var balance: Int

    public init(balance: Int = BankrollLedger.startingAmount) {
        self.balance = max(0, balance)
    }

    public var canAffordBuyIn: Bool { canAfford(BankrollLedger.buyIn) }

    public func canAfford(_ amount: Int) -> Bool { balance >= amount }

    /// Returns table chips to the bankroll (no-op for a busted stack of 0).
    public mutating func cashOut(_ tableChips: Int) {
        balance += max(0, tableChips)
    }

    /// Pays for a seat at the default stakes.
    @discardableResult
    public mutating func chargeBuyIn() -> Bool {
        chargeBuyIn(BankrollLedger.buyIn)
    }

    /// Pays for a seat. Returns false (and charges nothing) if the bankroll
    /// can't cover it — that's ruin, and the caller decides what to show.
    @discardableResult
    public mutating func chargeBuyIn(_ amount: Int) -> Bool {
        guard canAfford(amount) else { return false }
        balance -= amount
        return true
    }

    /// Total ruin acknowledged: start over with a fresh bankroll.
    public mutating func resetAfterRuin() {
        balance = BankrollLedger.startingAmount
    }
}
