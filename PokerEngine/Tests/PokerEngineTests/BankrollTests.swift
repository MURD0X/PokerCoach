import XCTest
@testable import PokerEngine

final class BankrollLedgerTests: XCTestCase {
    func testBuyInAndCashOutFlow() {
        var ledger = BankrollLedger()
        XCTAssertEqual(ledger.balance, 10_000)

        XCTAssertTrue(ledger.chargeBuyIn())
        XCTAssertEqual(ledger.balance, 9_000)

        // Leave the table having run 1,000 up to 2,350.
        ledger.cashOut(2_350)
        XCTAssertEqual(ledger.balance, 11_350)

        // Busting returns nothing.
        XCTAssertTrue(ledger.chargeBuyIn())
        ledger.cashOut(0)
        XCTAssertEqual(ledger.balance, 10_350)
    }

    func testRuinPathChargesNothingAndResets() {
        var ledger = BankrollLedger(balance: 900)
        XCTAssertFalse(ledger.canAffordBuyIn)
        XCTAssertFalse(ledger.chargeBuyIn())
        XCTAssertEqual(ledger.balance, 900, "a failed buy-in must not charge")

        ledger.resetAfterRuin()
        XCTAssertEqual(ledger.balance, 10_000)
        XCTAssertTrue(ledger.canAffordBuyIn)
    }

    func testNegativeInputsClamp() {
        var ledger = BankrollLedger(balance: -50)
        XCTAssertEqual(ledger.balance, 0)
        ledger.cashOut(-200)
        XCTAssertEqual(ledger.balance, 0)
    }
}

@MainActor
final class HeroRebuyTests: XCTestCase {
    func testRebuyRestoresStackAtSameTable() async {
        let engine = GameEngine(opponents: [
            ("A", .balanced), ("B", .balanced), ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        await engine.playHand()
        let tableNames = engine.players.map(\.name)

        engine.setStackForTesting(0, seat: 0)
        XCTAssertTrue(engine.heroBusted)

        engine.rebuyHero()
        XCTAssertFalse(engine.heroBusted)
        XCTAssertEqual(engine.hero.stack, GameEngine.startingStack)
        XCTAssertEqual(engine.players.map(\.name), tableNames, "rebuy keeps the same table")
        XCTAssertTrue(engine.log.contains { $0.text.contains("buy back in") })

        // Dealing works again.
        let before = engine.handNumber
        await engine.playHand()
        XCTAssertEqual(engine.handNumber, before + 1)
    }

    func testRebuyIgnoredWhenNotBusted() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        let stack = engine.hero.stack
        engine.rebuyHero()
        XCTAssertEqual(engine.hero.stack, stack, "rebuy is a no-op with chips behind")
    }
}
