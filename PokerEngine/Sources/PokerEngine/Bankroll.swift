import Foundation

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

    public var canAffordBuyIn: Bool { balance >= BankrollLedger.buyIn }

    /// Returns table chips to the bankroll (no-op for a busted stack of 0).
    public mutating func cashOut(_ tableChips: Int) {
        balance += max(0, tableChips)
    }

    /// Pays for a seat. Returns false (and charges nothing) if the bankroll
    /// can't cover it — that's ruin, and the caller decides what to show.
    @discardableResult
    public mutating func chargeBuyIn() -> Bool {
        guard canAffordBuyIn else { return false }
        balance -= BankrollLedger.buyIn
        return true
    }

    /// Total ruin acknowledged: start over with a fresh bankroll.
    public mutating func resetAfterRuin() {
        balance = BankrollLedger.startingAmount
    }
}
