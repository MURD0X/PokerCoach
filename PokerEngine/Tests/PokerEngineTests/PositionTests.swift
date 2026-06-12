import XCTest
@testable import PokerEngine

final class PositionTests: XCTestCase {
    func testSeatToPositionMapping() {
        // 4-handed, hero in seat 0.
        XCTAssertEqual(GameEngine.position(forSeat: 0, dealer: 0, count: 4), .button)
        XCTAssertEqual(GameEngine.position(forSeat: 0, dealer: 3, count: 4), .smallBlind)
        XCTAssertEqual(GameEngine.position(forSeat: 0, dealer: 2, count: 4), .bigBlind)
        XCTAssertEqual(GameEngine.position(forSeat: 0, dealer: 1, count: 4), .early)
    }

    func testTiersLoosenTowardTheButton() {
        // Every score must play at least as strongly on the button as up front.
        for score in 0...20 {
            XCTAssertGreaterThanOrEqual(
                Coach.preflopTier(score: score, position: .button),
                Coach.preflopTier(score: score, position: .early),
                "score \(score) tighter on the button than under the gun"
            )
        }
    }

    func testSameHandDifferentAdviceByPosition() {
        // K♠J♦ = Chen 7: playable on the button (effective 8.5 → strong),
        // marginal under the gun (effective 6 → barely playable).
        let hole = [Card(13, .spades), Card(11, .diamonds)]
        XCTAssertEqual(Chen.score(hole), 7)

        let button = Coach.preflopAdvice(hole: hole, toCall: 20, bigBlind: 20, position: .button)
        let early = Coach.preflopAdvice(hole: hole, toCall: 80, bigBlind: 20, position: .early)
        XCTAssertEqual(button.action, .raise, "Chen 7 on the button should attack")
        XCTAssertEqual(early.action, .fold, "Chen 7 facing a 4BB raise up front should fold")
    }

    func testAdviceMentionsPosition() {
        let advice = Coach.preflopAdvice(
            hole: [Card(14, .spades), Card(14, .hearts)],
            toCall: 20, bigBlind: 20, position: .early
        )
        XCTAssertTrue(advice.lines.contains { $0.contains("under the gun") })
    }
}
