import XCTest
@testable import PokerEngine

final class DrillGeneratorTests: XCTestCase {
    func testSpotsAreInternallyConsistent() {
        for _ in 0..<50 {
            let spot = DrillGenerator.spot()
            // No duplicate cards between hole and board.
            let all = spot.hole + spot.board
            XCTAssertEqual(Set(all).count, all.count, "duplicate cards in spot")
            XCTAssertEqual(spot.hole.count, 2)
            XCTAssertTrue([0, 3, 4, 5].contains(spot.board.count))
            XCTAssertGreaterThan(spot.pot, 0)
            XCTAssertGreaterThanOrEqual(spot.toCall, 0)
            XCTAssertFalse(spot.advice.lines.isEmpty, "advice must explain itself")
        }
    }

    func testPreflopSpotsCarryChenAndPosition() {
        var positions = Set<Position>()
        for _ in 0..<40 {
            let spot = DrillGenerator.preflopSpot()
            XCTAssertTrue(spot.isPreflop)
            XCTAssertNotNil(spot.advice.chenScore)
            positions.insert(spot.position)
        }
        XCTAssertGreaterThan(positions.count, 1, "positions should vary")
    }

    func testPostflopSpotsCarryEquity() {
        for _ in 0..<10 {
            let spot = DrillGenerator.postflopSpot()
            XCTAssertFalse(spot.isPreflop)
            XCTAssertNotNil(spot.advice.equity)
            if spot.toCall > 0 {
                XCTAssertNotNil(spot.advice.potOddsNeeded)
                XCTAssertLessThan(spot.toCall, spot.pot + spot.toCall)
            }
        }
    }

    func testUserAnswersGradeThroughReviewer() {
        let spot = DrillGenerator.postflopSpot()
        let review = Reviewer.review(
            recommendation: spot.advice.action, action: .checkCall,
            equity: spot.advice.equity, potOddsNeeded: spot.advice.potOddsNeeded,
            street: spot.street
        )
        XCTAssertFalse(review.line.isEmpty)
    }
}
