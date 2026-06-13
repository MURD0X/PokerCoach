import XCTest
@testable import PokerEngine

final class PersonalityTests: XCTestCase {
    func testRandomRollsStayInRange() {
        for _ in 0..<200 {
            let p = Personality.random()
            XCTAssertTrue((0...1).contains(p.tightness))
            XCTAssertTrue((0...1).contains(p.aggression))
            XCTAssertTrue((0...1).contains(p.skill))
        }
    }

    func testTraitLabels() {
        let shark = Personality(tightness: 0.9, aggression: 0.9, skill: 0.9)
        XCTAssertEqual(shark.styleName, "Tight · Aggressive · Expert")
        let station = Personality(tightness: 0.1, aggression: 0.1, skill: 0.1)
        XCTAssertEqual(station.styleName, "Loose · Passive · Rookie")
        let mid = Personality(tightness: 0.5, aggression: 0.5, skill: 0.5)
        XCTAssertEqual(mid.styleName, "Balanced · Measured · Solid")
    }

    func testAxesShapeDecisionParametersMonotonically() {
        let tight = Personality(tightness: 1, aggression: 0.5, skill: 0.5)
        let loose = Personality(tightness: 0, aggression: 0.5, skill: 0.5)
        XCTAssertGreaterThan(tight.preflopRaiseThreshold, loose.preflopRaiseThreshold)
        XCTAssertGreaterThan(tight.preflopCallThreshold, loose.preflopCallThreshold)
        XCTAssertLessThan(tight.speculativeCallRate, loose.speculativeCallRate)

        let aggro = Personality(tightness: 0.5, aggression: 1, skill: 0.5)
        let passive = Personality(tightness: 0.5, aggression: 0, skill: 0.5)
        XCTAssertGreaterThan(aggro.bluffRate, passive.bluffRate)
        XCTAssertLessThan(aggro.valueBetThreshold, passive.valueBetThreshold)
        XCTAssertGreaterThan(aggro.raiseWithStrengthRate, passive.raiseWithStrengthRate)

        let expert = Personality(tightness: 0.5, aggression: 0.5, skill: 1)
        let rookie = Personality(tightness: 0.5, aggression: 0.5, skill: 0)
        XCTAssertGreaterThan(expert.potOddsDiscipline, rookie.potOddsDiscipline)
        XCTAssertLessThan(expert.equityNoise, rookie.equityNoise)
        XCTAssertGreaterThan(expert.equityTrials, rookie.equityTrials)
    }

    func testRandomLineupHasDistinctNames() {
        for _ in 0..<50 {
            let lineup = OpponentFactory.randomLineup(count: 3)
            XCTAssertEqual(lineup.count, 3)
            XCTAssertEqual(Set(lineup.map(\.name)).count, 3)
        }
    }

    func testRandomLineupRespectsExclusions() {
        let excluded: Set<String> = ["Maya", "Dmitri", "Rosa", "Omar", "Wei"]
        for _ in 0..<100 {
            let lineup = OpponentFactory.randomLineup(count: 3, excluding: excluded)
            XCTAssertTrue(lineup.allSatisfy { !excluded.contains($0.name) })
        }
    }

    func testLineupsVaryAcrossSessions() {
        // 10 independent lineups (as if 10 app launches) should not all be
        // identical. With 60 names the chance of a false failure is ~0.
        let lineups = (0..<10).map { _ in OpponentFactory.randomLineup(count: 3).map(\.name) }
        XCTAssertGreaterThan(Set(lineups).count, 1, "every session produced the same table")
    }
}

@MainActor
final class PersonalityBehaviorTests: XCTestCase {
    // A maximally tight player should fold far more often than a maximally
    // loose one over many hands. Statistical, with a wide margin.
    func testTightPlayersFoldMoreThanLoosePlayers() async {
        let engine = GameEngine(opponents: [
            ("Nit", Personality(tightness: 1, aggression: 0.3, skill: 0.8)),
            ("Gambler", Personality(tightness: 0, aggression: 0.3, skill: 0.8)),
            ("Mid", Personality(tightness: 0.5, aggression: 0.5, skill: 0.5)),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }

        var nitFolds = 0, gamblerFolds = 0
        for _ in 0..<40 {
            topUpAllStacks(engine)
            await engine.playHand()
            nitFolds += engine.log.filter { $0.text == "Nit folds." }.count
            gamblerFolds += engine.log.filter { $0.text == "Gambler folds." }.count
        }
        XCTAssertGreaterThan(nitFolds, gamblerFolds,
            "tightness=1 player folded \(nitFolds)x vs \(gamblerFolds)x for tightness=0")
    }

    func testStyleRevealUnlocksWithEvidence() async {
        let personality = Personality(tightness: 0.9, aggression: 0.2, skill: 0.9)
        let engine = GameEngine(opponents: [
            ("Target", personality),
            ("B", .balanced),
            ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }

        // Nothing known before any hands.
        let initial = engine.styleReveal(for: 1)
        XCTAssertNil(initial.tightness)
        XCTAssertNil(initial.aggression)
        XCTAssertNil(initial.skill)
        XCTAssertEqual(initial.summary, "? · ? · ?")

        for _ in 0..<15 {
            topUpAllStacks(engine)
            await engine.playHand()
        }

        let reveal = engine.styleReveal(for: 1)
        // 15 hands seen — tightness must be revealed, and truthfully.
        XCTAssertEqual(reveal.tightness, "Tight")
        // Aggression reveals after 10 observed decisions (each hand has ≥1).
        XCTAssertEqual(reveal.aggression, "Passive")
        // Skill needs 3 showdowns; assert the gating is honest either way.
        let target = engine.players[1]
        if target.showdownsShown >= 3 {
            XCTAssertEqual(reveal.skill, "Expert")
        } else {
            XCTAssertNil(reveal.skill)
        }
        // The hero never gets a reveal entry.
        XCTAssertFalse(engine.styleReveal(for: 0).anythingKnown)
    }

    func testBustedOpponentIsReplacedByNewPlayer() async {
        let engine = GameEngine(opponents: [
            ("Doomed", .balanced), ("B", .balanced), ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        engine.setStackForTesting(0, seat: 1)

        await engine.playHand()

        let replacement = engine.players[1]
        XCTAssertNotEqual(replacement.name, "Doomed", "busted opponent should leave")
        XCTAssertNotNil(replacement.personality)
        // Fresh player: reveal evidence starts over (1 hand seen = this hand).
        XCTAssertLessThanOrEqual(replacement.handsSeen, 1)
        XCTAssertEqual(replacement.showdownsShown <= 1, true)
        XCTAssertFalse(engine.styleReveal(for: 1).anythingKnown)
        XCTAssertTrue(engine.log.contains { $0.text.contains("leaves the table") })
        // Seat identity is stable for the UI.
        XCTAssertEqual(replacement.id, 1)
    }

    func testEngineRefusesToDealWhenHeroBusted() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        engine.setStackForTesting(0, seat: 0)

        XCTAssertTrue(engine.heroBusted)
        await engine.playHand()
        XCTAssertEqual(engine.handNumber, 0, "no hand should be dealt while the hero is busted")

        // A new table resets the session and dealing works again.
        engine.newTable()
        XCTAssertFalse(engine.heroBusted)
        await engine.playHand()
        XCTAssertEqual(engine.handNumber, 1)
    }

    func testNewTableResetsEverything() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        for _ in 0..<3 {
            topUpAllStacks(engine)
            await engine.playHand()
        }
        XCTAssertEqual(engine.handNumber, 3)

        let oldNames = Set(engine.players.dropFirst().map(\.name))
        engine.newTable()
        let rerolled = Set(engine.players.dropFirst().map(\.name))
        XCTAssertTrue(rerolled.isDisjoint(with: oldNames), "re-rolled table repeated a current opponent")

        engine.newTable(opponents: [
            ("Newcomer", .balanced), ("Fresh", .balanced), ("Unknown", .balanced),
        ])
        XCTAssertEqual(engine.stage, .idle)
        XCTAssertEqual(engine.handNumber, 0)
        XCTAssertNil(engine.lastResult)
        XCTAssertEqual(engine.players.map(\.name), ["You", "Newcomer", "Fresh", "Unknown"])
        XCTAssertTrue(engine.players.allSatisfy { $0.stack == GameEngine.startingStack })
        XCTAssertTrue(engine.players.dropFirst().allSatisfy { $0.handsSeen == 0 })
        XCTAssertFalse(engine.styleReveal(for: 1).anythingKnown)
    }
}

@MainActor
final class StyleReadingTests: XCTestCase {
    func testReadingShowsProgressThenReveals() async {
        let engine = GameEngine(opponents: [
            ("T", Personality(tightness: 0.9, aggression: 0.2, skill: 0.9)),
            ("B", .balanced), ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }

        // Before any hands: all three dials hidden, each with a hint.
        let cold = engine.styleReading(for: 1)
        XCTAssertEqual(cold.dials.count, 3)
        XCTAssertTrue(cold.dials.allSatisfy { !$0.isRevealed })
        XCTAssertTrue(cold.dials.allSatisfy { ($0.progressHint ?? "").contains("to learn") })
        XCTAssertTrue(cold.dials[0].progressHint!.contains("8 more hands"))

        for _ in 0..<15 {
            topUpAllStacks(engine)
            await engine.playHand()
        }

        let warm = engine.styleReading(for: 1)
        // Hand selection revealed after 8 hands; its hint is gone.
        XCTAssertEqual(warm.dials[0].value, "Tight")
        XCTAssertNil(warm.dials[0].progressHint)
        // The hero has no dials.
        XCTAssertTrue(engine.styleReading(for: 0).dials.isEmpty)
    }
}
