import XCTest
@testable import PokerEngine

final class TournamentStateTests: XCTestCase {
    func testBlindLadderAdvancesOnSchedule() {
        var t = TournamentState()
        XCTAssertEqual(t.blinds.bb, 20)
        XCTAssertEqual(t.level, 1)
        for _ in 0..<5 { t.handCompleted() }
        XCTAssertEqual(t.level, 1, "still level 1 after 5 hands")
        t.handCompleted()                       // 6th hand
        XCTAssertEqual(t.level, 2)
        XCTAssertEqual(t.blinds.sb, 15)
        XCTAssertEqual(t.blinds.bb, 30)
    }

    func testPayoutSplit() {
        XCTAssertEqual(TournamentState.pool, 4000)
        XCTAssertEqual(TournamentState.payout(place: 0), 2600)
        XCTAssertEqual(TournamentState.payout(place: 1), 1400)
        XCTAssertEqual(TournamentState.payout(place: 2), 0)
        XCTAssertEqual(TournamentState.payouts.reduce(0, +), TournamentState.pool)
    }
}

final class SeatRolesTests: XCTestCase {
    func testFourHandedMatchesCashRotation() {
        // Button at seat 0: SB=1, BB=2, preflop UTG=3, postflop SB=1.
        let r = GameEngine.seatRoles(activeSeats: [0,1,2,3], button: 0)
        XCTAssertEqual([r.sb, r.bb, r.preflopFirst, r.postflopFirst], [1, 2, 3, 1])
    }

    func testThreeHanded() {
        let r = GameEngine.seatRoles(activeSeats: [0,2,3], button: 2)  // seat 1 eliminated
        XCTAssertEqual(r.sb, 3)
        XCTAssertEqual(r.bb, 0)
        XCTAssertEqual(r.preflopFirst, 2)   // button acts first preflop 3-handed
        XCTAssertEqual(r.postflopFirst, 3)  // SB first postflop
    }

    func testHeadsUpButtonIsSmallBlind() {
        let r = GameEngine.seatRoles(activeSeats: [0,3], button: 0)
        XCTAssertEqual(r.sb, 0, "button posts the small blind heads-up")
        XCTAssertEqual(r.bb, 3)
        XCTAssertEqual(r.preflopFirst, 0, "SB acts first preflop heads-up")
        XCTAssertEqual(r.postflopFirst, 3, "BB acts first postflop heads-up")
    }
}

@MainActor
final class TournamentEngineTests: XCTestCase {
    func testTournamentRunsToOneWinner() async {
        let engine = GameEngine(opponents: [
            ("A", .balanced), ("B", .balanced), ("C", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        engine.beginTournament(startingStack: TournamentState.startingStack, sb: 10, bb: 20)

        var t = TournamentState()
        var hands = 0
        while engine.activePlayerCount > 1 && hands < 400 {
            engine.setBlindLevel(sb: t.blinds.sb, bb: t.blinds.bb)
            await engine.playHand()
            t.handCompleted()
            hands += 1
            // Chip total is always conserved at the field's buy-ins.
            let chips = engine.players.reduce(0) { $0 + $1.stack }
            XCTAssertEqual(chips, TournamentState.startingStack * 4, "chips conserved (hand \(hands))")
        }
        XCTAssertEqual(engine.activePlayerCount, 1, "exactly one player left standing")
        XCTAssertLessThan(hands, 400, "tournament terminated")
        // The survivor holds every chip.
        let champ = engine.players.first { !$0.eliminated }!
        XCTAssertEqual(champ.stack, TournamentState.startingStack * 4)
    }

    func testEliminatedPlayersStayOut() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        engine.beginTournament(startingStack: 1000, sb: 10, bb: 20)
        engine.setStackForTesting(0, seat: 2)
        await engine.playHand()
        XCTAssertTrue(engine.players[2].eliminated)
        // An eliminated seat is never dealt cards on subsequent hands.
        for _ in 0..<5 where engine.activePlayerCount > 1 {
            await engine.playHand()
            XCTAssertTrue(engine.players[2].hole.isEmpty, "eliminated seat dealt cards")
        }
    }

    func testForfeitHeroEliminatesHeroAndKeepsOthers() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        engine.beginTournament(startingStack: 1000, sb: 10, bb: 20)
        let before = engine.activePlayerCount

        engine.forfeitHero()

        XCTAssertTrue(engine.players[0].eliminated, "hero is out after forfeiting")
        XCTAssertEqual(engine.players[0].stack, 0, "forfeited stack is surrendered")
        XCTAssertEqual(engine.activePlayerCount, before - 1, "only the hero leaves")
        // The remaining field plays on to a single winner.
        var hands = 0
        while engine.activePlayerCount > 1 && hands < 400 {
            await engine.playHand()
            XCTAssertTrue(engine.players[0].hole.isEmpty, "forfeited hero dealt cards")
            hands += 1
        }
        XCTAssertEqual(engine.activePlayerCount, 1, "field resolves to one winner")
    }

    func testForfeitHeroIgnoredInCashMode() {
        let engine = GameEngine()        // cash mode by default
        engine.forfeitHero()
        XCTAssertFalse(engine.players[0].eliminated, "forfeit is tournament-only")
    }
}
