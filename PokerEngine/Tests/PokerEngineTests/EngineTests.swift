import XCTest
@testable import PokerEngine

private func c(_ rank: Int, _ suit: Suit) -> Card { Card(rank, suit) }

final class HandEvaluatorTests: XCTestCase {
    func assertHand(_ cards: [Card], _ category: HandCategory, _ name: String,
                    file: StaticString = #filePath, line: UInt = #line) {
        let score = HandEvaluator.evaluate5(cards)
        XCTAssertEqual(HandEvaluator.category(of: score), category, file: file, line: line)
        XCTAssertEqual(HandEvaluator.name(of: score), name, file: file, line: line)
    }

    func testAllCategories() {
        assertHand([c(14, .spades), c(13, .spades), c(12, .spades), c(11, .spades), c(10, .spades)],
                   .straightFlush, "Royal Flush")
        assertHand([c(14, .hearts), c(2, .hearts), c(3, .hearts), c(4, .hearts), c(5, .hearts)],
                   .straightFlush, "Five-high Straight Flush")
        assertHand([c(12, .spades), c(12, .hearts), c(12, .diamonds), c(12, .clubs), c(7, .diamonds)],
                   .fourOfAKind, "Four Queens")
        assertHand([c(11, .spades), c(11, .hearts), c(11, .diamonds), c(4, .clubs), c(4, .hearts)],
                   .fullHouse, "Full House, Jacks over Fours")
        assertHand([c(14, .clubs), c(11, .clubs), c(8, .clubs), c(6, .clubs), c(2, .clubs)],
                   .flush, "Ace-high Flush")
        assertHand([c(8, .spades), c(7, .diamonds), c(6, .clubs), c(5, .hearts), c(4, .spades)],
                   .straight, "Eight-high Straight")
        assertHand([c(14, .spades), c(2, .diamonds), c(3, .clubs), c(4, .hearts), c(5, .spades)],
                   .straight, "Five-high Straight")
        assertHand([c(7, .spades), c(7, .hearts), c(7, .diamonds), c(13, .clubs), c(2, .hearts)],
                   .threeOfAKind, "Three Sevens")
        assertHand([c(14, .spades), c(14, .diamonds), c(9, .clubs), c(9, .hearts), c(12, .spades)],
                   .twoPair, "Two Pair, Aces and Nines")
        assertHand([c(10, .spades), c(10, .clubs), c(14, .diamonds), c(6, .hearts), c(3, .spades)],
                   .pair, "Pair of Tens")
        assertHand([c(14, .hearts), c(11, .diamonds), c(8, .spades), c(5, .clubs), c(2, .diamonds)],
                   .highCard, "Ace High")
    }

    func testTiebreakers() {
        let pairKings = HandEvaluator.evaluate5([c(13, .spades), c(13, .hearts), c(9, .diamonds), c(6, .hearts), c(3, .spades)])
        let pairNines = HandEvaluator.evaluate5([c(9, .spades), c(9, .hearts), c(13, .diamonds), c(6, .hearts), c(3, .spades)])
        XCTAssertGreaterThan(pairKings, pairNines)

        // Same pair, better kicker wins.
        let aceKicker = HandEvaluator.evaluate5([c(8, .spades), c(8, .hearts), c(14, .diamonds), c(6, .hearts), c(3, .spades)])
        let kingKicker = HandEvaluator.evaluate5([c(8, .diamonds), c(8, .clubs), c(13, .clubs), c(6, .spades), c(3, .hearts)])
        XCTAssertGreaterThan(aceKicker, kingKicker)

        // Wheel is the lowest straight.
        let wheel = HandEvaluator.evaluate5([c(14, .spades), c(2, .diamonds), c(3, .clubs), c(4, .hearts), c(5, .spades)])
        let sixHigh = HandEvaluator.evaluate5([c(2, .spades), c(3, .diamonds), c(4, .clubs), c(5, .hearts), c(6, .spades)])
        XCTAssertGreaterThan(sixHigh, wheel)
    }

    func testSevenCardEvaluation() {
        // Hole pair + board trips = full house, threes full of eights.
        let seven = HandEvaluator.bestScore([
            c(8, .spades), c(8, .hearts),
            c(3, .spades), c(3, .hearts), c(3, .diamonds), c(12, .clubs), c(5, .spades),
        ])
        XCTAssertEqual(HandEvaluator.name(of: seven), "Full House, Threes over Eights")

        let (score, hand) = HandEvaluator.best([
            c(14, .clubs), c(2, .clubs),
            c(7, .clubs), c(9, .clubs), c(11, .clubs), c(11, .spades), c(11, .diamonds),
        ])
        XCTAssertEqual(HandEvaluator.category(of: score), .flush)
        XCTAssertEqual(hand.count, 5)
        XCTAssertTrue(hand.allSatisfy { $0.suit == .clubs })
    }

    func testDeckIntegrity() {
        let deck = Deck.shuffled()
        XCTAssertEqual(deck.count, 52)
        XCTAssertEqual(Set(deck).count, 52)
    }
}

final class ChenTests: XCTestCase {
    func testKnownScores() {
        XCTAssertEqual(Chen.score([c(14, .spades), c(14, .hearts)]), 20) // AA
        XCTAssertEqual(Chen.score([c(14, .spades), c(13, .spades)]), 12) // AKs
        XCTAssertEqual(Chen.score([c(11, .spades), c(11, .hearts)]), 12) // JJ
        XCTAssertEqual(Chen.score([c(2, .spades), c(2, .hearts)]), 5)   // 22 floors at 5
        XCTAssertLessThanOrEqual(Chen.score([c(7, .spades), c(2, .hearts)]), 0) // 72o, worst hand
    }
}

final class EquityTests: XCTestCase {
    func testPocketAcesHeadsUp() {
        // AA vs one random hand is ~85% to win.
        let result = Equity.estimate(hole: [c(14, .spades), c(14, .hearts)], board: [], opponents: 1, trials: 3000)
        XCTAssertGreaterThan(result.win, 0.80)
        XCTAssertLessThan(result.win, 0.90)
    }

    func testMadeNutsIsNearCertain() {
        // Royal flush on the river loses to nothing.
        let result = Equity.estimate(
            hole: [c(14, .spades), c(13, .spades)],
            board: [c(12, .spades), c(11, .spades), c(10, .spades), c(2, .hearts), c(7, .diamonds)],
            opponents: 3, trials: 500
        )
        XCTAssertEqual(result.win, 1.0, accuracy: 0.001)
    }
}

final class OutsTests: XCTestCase {
    func testFlushDraw() {
        // 4 hearts: exactly 9 hearts remain as flush outs.
        let outs = Outs.compute(
            hole: [c(14, .hearts), c(7, .hearts)],
            board: [c(2, .hearts), c(9, .hearts), c(13, .clubs)]
        )
        let flushOuts = outs.filter { $0.makes == .flush }
        XCTAssertEqual(flushOuts.count, 9)
        XCTAssertTrue(flushOuts.allSatisfy { $0.card.suit == .hearts })
    }

    func testBoardOnlyImprovementDoesNotCount() {
        // Hero's hole cards are irrelevant to the board pairing: 2♦ pairing the
        // board improves the "best five" but must use a hole card to count.
        let outs = Outs.compute(
            hole: [c(14, .spades), c(13, .hearts)],
            board: [c(2, .clubs), c(7, .diamonds), c(9, .spades)]
        )
        XCTAssertFalse(outs.contains { $0.card.rank == 2 })
        // Pairing an ace or king does count.
        XCTAssertTrue(outs.contains { $0.card.rank == 14 })
        XCTAssertTrue(outs.contains { $0.card.rank == 13 })
    }
}

final class SidePotTests: XCTestCase {
    func testSimpleSidePot() {
        // A all-in for 100; B and C continue to 300 each.
        let pots = GameEngine.buildPots(contributions: [
            (100, false, 0), (300, false, 1), (300, false, 2),
        ])
        XCTAssertEqual(pots.count, 2)
        XCTAssertEqual(pots[0].amount, 300)
        XCTAssertEqual(Set(pots[0].eligible), [0, 1, 2])
        XCTAssertEqual(pots[1].amount, 400)
        XCTAssertEqual(Set(pots[1].eligible), [1, 2])
        XCTAssertEqual(pots.reduce(0) { $0 + $1.amount }, 700)
    }

    func testFoldedChipsGoToPotWithoutEligibility() {
        // D folded after putting in 50; that money is in the main pot but D can't win.
        let pots = GameEngine.buildPots(contributions: [
            (200, false, 0), (200, false, 1), (50, true, 2),
        ])
        XCTAssertEqual(pots.count, 1)
        XCTAssertEqual(pots[0].amount, 450)
        XCTAssertEqual(Set(pots[0].eligible), [0, 1])
    }

    func testFoldedOverhangAddsToLastPot() {
        // Folder contributed more than the smallest all-in.
        let pots = GameEngine.buildPots(contributions: [
            (100, false, 0), (300, false, 1), (250, true, 2),
        ])
        XCTAssertEqual(pots.reduce(0) { $0 + $1.amount }, 650)
        XCTAssertEqual(Set(pots[0].eligible), [0, 1])
        XCTAssertEqual(Set(pots[1].eligible), [1])
    }
}

@MainActor
final class GameFlowTests: XCTestCase {
    func testFullHandsConserveChips() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        // Scripted hero: always check/call so every hand reaches showdown or fold-win.
        engine.heroActionProvider = { .checkCall }
        for _ in 0..<25 {
            await engine.playHand()
            XCTAssertEqual(engine.stage, .done)
            let total = engine.players.reduce(0) { $0 + $1.stack + $1.totalBet }
            // Chips conserved modulo rebuys (rebuys add exactly startingStack).
            XCTAssertEqual(total % 10, 0)
            XCTAssertGreaterThanOrEqual(total, 4 * GameEngine.startingStack)
            XCTAssertEqual(engine.players.filter { $0.stack < 0 }.count, 0)
        }
    }

    func testHeroRaisesAreApplied() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        var raised = false
        engine.heroActionProvider = {
            if !raised {
                raised = true
                return .raise(to: 60)
            }
            return .checkCall
        }
        await engine.playHand()
        XCTAssertEqual(engine.stage, .done)
        XCTAssertTrue(engine.log.contains { $0.text.contains("You") && ($0.text.contains("raises") || $0.text.contains("bets")) })
    }
}
