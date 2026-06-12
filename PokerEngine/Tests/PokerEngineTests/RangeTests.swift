import XCTest
@testable import PokerEngine

final class RangeConstraintTests: XCTestCase {
    func testActionToConstraintMapping() {
        XCTAssertEqual(GameEngine.constraint(for: .raised, revealedTightness: nil).minChen, 8)
        XCTAssertEqual(GameEngine.constraint(for: .raised, revealedTightness: "Tight").minChen, 9)
        XCTAssertEqual(GameEngine.constraint(for: .raised, revealedTightness: "Loose").minChen, 6)
        XCTAssertEqual(GameEngine.constraint(for: .called, revealedTightness: nil).minChen, 5)
        XCTAssertNil(GameEngine.constraint(for: .checked, revealedTightness: nil).minChen)
        XCTAssertNil(GameEngine.constraint(for: .none, revealedTightness: "Tight").minChen)
    }

    func testConstrainedRangeLowersWeakHandEquity() {
        // 7♦2♣ vs one random hand is mediocre; vs a raising range (Chen ≥ 8)
        // it must be clearly worse. Statistical with a wide margin.
        let hole = [Card(7, .diamonds), Card(2, .clubs)]
        let vsRandom = Equity.estimate(hole: hole, board: [], opponents: 1, trials: 6000)
        let vsRaiser = Equity.estimate(hole: hole, board: [], opponents: 1, trials: 6000,
                                       constraints: [RangeConstraint(minChen: 8)])
        XCTAssertLessThan(vsRaiser.decisionEquity, vsRandom.decisionEquity - 0.04,
            "vs raiser \(vsRaiser.decisionEquity) should be well below vs random \(vsRandom.decisionEquity)")
    }

    func testAnyConstraintMatchesUnconstrained() {
        let hole = [Card(13, .spades), Card(12, .spades)]
        let plain = Equity.estimate(hole: hole, board: [], opponents: 2, trials: 6000)
        let any = Equity.estimate(hole: hole, board: [], opponents: 2, trials: 6000,
                                  constraints: [.any, .any])
        XCTAssertEqual(plain.decisionEquity, any.decisionEquity, accuracy: 0.04)
    }

    func testStrongHandStaysStrongVsRaiser() {
        // AA is still a big favorite even against a premium range.
        let hole = [Card(14, .spades), Card(14, .hearts)]
        let vsRaiser = Equity.estimate(hole: hole, board: [], opponents: 1, trials: 4000,
                                       constraints: [RangeConstraint(minChen: 8)])
        XCTAssertGreaterThan(vsRaiser.win, 0.65)
    }
}

@MainActor
final class PreflopActionTrackingTests: XCTestCase {
    func testActionsRecordedForShowdownPlayers() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }

        var verified = false
        for _ in 0..<12 where !verified {
            topUpAllStacks(engine)
            await engine.playHand()
            guard let result = engine.lastResult, !result.wonByFolds else { continue }
            // Everyone who reached showdown acted preflop, so their action
            // must be recorded (checked, called, or raised — never none).
            for show in result.showdowns {
                let player = engine.players[show.playerID]
                XCTAssertNotEqual(player.preflopAction, PreflopAction.none,
                    "\(player.name) reached showdown without a recorded preflop action")
            }
            verified = true
        }
        XCTAssertTrue(verified, "no showdown reached in 12 hands")
    }

    func testHeroRaiseRecorded() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        var acted = false
        engine.heroActionProvider = {
            acted = true
            return .raise(to: 60)
        }
        for _ in 0..<20 where !acted {
            topUpAllStacks(engine)
            await engine.playHand()
        }
        if !acted { await engine.playHand() }
        XCTAssertTrue(acted)
        XCTAssertEqual(engine.hero.preflopAction, .raised)
    }
}

@MainActor
final class RaiseProgressTests: XCTestCase {
    // Regression for an infinite betting loop: a hero who stubbornly answers
    // "raise to 60" forever — even when 60 is below the current bet and the
    // stack can't make a legal min-raise — must still complete every hand
    // (the engine normalizes the request to a raise, all-in, or call).
    func testStubbornUnderMinRaiserCannotHangTheHand() async {
        let engine = GameEngine(opponents: [
            ("A", Personality(tightness: 0.2, aggression: 1.0, skill: 0.5)),
            ("B", Personality(tightness: 0.2, aggression: 1.0, skill: 0.5)),
            ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .raise(to: 60) }

        for _ in 0..<15 {
            topUpAllStacks(engine)
            // Guard with a timeout so a regression fails fast instead of
            // hanging the whole suite.
            let completed = await withTaskGroup(of: Bool.self) { group in
                group.addTask { @MainActor in
                    await engine.playHand()
                    return true
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(20))
                    return false
                }
                let first = await group.next()!
                group.cancelAll()
                return first
            }
            XCTAssertTrue(completed, "hand \(engine.handNumber + 1) did not complete — betting loop hang")
            if !completed { break }
        }
    }
}
