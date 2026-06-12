import XCTest
@testable import PokerEngine

@MainActor
final class TableSnapshotTests: XCTestCase {
    func testSnapshotRestoreRoundTrip() async throws {
        let engine = GameEngine(stakes: .high, opponents: [
            ("Vera", Personality(tightness: 0.9, aggression: 0.1, skill: 0.8)),
            ("Tomas", Personality(tightness: 0.2, aggression: 0.9, skill: 0.3)),
            ("Lena", .balanced),
        ])
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }
        for _ in 0..<10 {
            topUpAllStacks(engine)
            await engine.playHand()
        }

        guard let snapshot = engine.snapshot() else { return XCTFail("snapshot unavailable between hands") }
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameEngine.TableSnapshot.self, from: data)

        let restored = GameEngine()
        restored.aiDelay = .zero
        restored.heroActionProvider = { .checkCall }
        restored.restore(decoded)

        XCTAssertEqual(restored.stakes, .high)
        XCTAssertEqual(restored.handNumber, engine.handNumber)
        XCTAssertEqual(restored.players.map(\.name), engine.players.map(\.name))
        XCTAssertEqual(restored.players.map(\.stack), engine.players.map(\.stack))
        XCTAssertEqual(restored.players[1].personality, engine.players[1].personality)
        // Reveal evidence survives: 10 hands seen means tightness is known.
        XCTAssertEqual(restored.styleReveal(for: 1).tightness, "Tight")
        // The restored table plays on. (Top up first: if the hero happened
        // to bust on the last looped hand, the restored engine correctly
        // refuses to deal — that's the app's bust-sheet path, not a bug.)
        topUpAllStacks(restored)
        let before = restored.handNumber
        await restored.playHand()
        XCTAssertEqual(restored.handNumber, before + 1)
    }

    func testSnapshotUnavailableMidHand() async {
        let engine = GameEngine()
        engine.aiDelay = .zero
        engine.heroActionProvider = { [weak engine] in
            // Mid-hand: the snapshot API must refuse.
            XCTAssertNil(engine?.snapshot())
            return .checkCall
        }
        topUpAllStacks(engine)
        await engine.playHand()
        XCTAssertNotNil(engine.snapshot())
    }
}
