import XCTest
@testable import PokerEngine

final class TableStakesTests: XCTestCase {
    func testStakesDefinitions() {
        XCTAssertEqual(TableStakes.low.buyIn, 500)
        XCTAssertEqual(TableStakes.standard.buyIn, 1000)
        XCTAssertEqual(TableStakes.high.buyIn, 2500)
        XCTAssertEqual(TableStakes.standard.name, "10/20")
        XCTAssertEqual(TableStakes.all.count, 3)
    }

    func testBankrollFractionGuidance() {
        // 2,500 buy-in from a 10,000 bankroll = 25% — over the 10% guideline.
        XCTAssertEqual(TableStakes.high.bankrollFraction(of: 10_000), 0.25, accuracy: 0.001)
        XCTAssertEqual(TableStakes.low.bankrollFraction(of: 10_000), 0.05, accuracy: 0.001)
        XCTAssertEqual(TableStakes.standard.bankrollFraction(of: 0), 1)
    }

    func testLedgerChargesVariableBuyIns() {
        var ledger = BankrollLedger()
        XCTAssertTrue(ledger.chargeBuyIn(TableStakes.high.buyIn))
        XCTAssertEqual(ledger.balance, 7_500)
        XCTAssertTrue(ledger.chargeBuyIn(TableStakes.low.buyIn))
        XCTAssertEqual(ledger.balance, 7_000)
        var poor = BankrollLedger(balance: 600)
        XCTAssertFalse(poor.chargeBuyIn(TableStakes.standard.buyIn))
        XCTAssertEqual(poor.balance, 600)
        XCTAssertTrue(poor.chargeBuyIn(TableStakes.low.buyIn))
    }
}

@MainActor
final class HighStakesGameTests: XCTestCase {
    func testHighStakesTablePlaysWithItsBlinds() async {
        let engine = GameEngine(stakes: .high)
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }

        XCTAssertEqual(engine.stakes.bigBlind, 50)
        XCTAssertTrue(engine.players.allSatisfy { $0.stack == 2_500 })

        for _ in 0..<10 {
            for i in engine.players.indices where engine.players[i].stack == 0 {
                engine.setStackForTesting(TableStakes.high.buyIn, seat: i)
            }
            await engine.playHand()
            XCTAssertEqual(engine.stage, .done)
        }
        XCTAssertTrue(engine.log.contains { $0.text.contains("small blind 25") },
            "high-stakes blinds should be posted at 25/50")
    }

    func testNewTableCanChangeStakes() async {
        let engine = GameEngine(stakes: .standard)
        engine.aiDelay = .zero
        engine.newTable(stakes: .high)
        XCTAssertEqual(engine.stakes, .high)
        XCTAssertTrue(engine.players.allSatisfy { $0.stack == 2_500 })
        // Without a stakes argument, the table keeps its current stakes.
        engine.newTable()
        XCTAssertEqual(engine.stakes, .high)
    }
}
