import XCTest
@testable import PokerEngine

final class ReviewerTests: XCTestCase {
    func testFollowedDecisions() {
        let r = Reviewer.review(recommendation: .call, action: .checkCall,
                                equity: 0.42, potOddsNeeded: 0.25, street: .turn)
        XCTAssertEqual(r.verdict, .followed)
        XCTAssertTrue(r.line.contains("42%"))
        XCTAssertEqual(r.severity, 0)
        XCTAssertEqual(Reviewer.review(recommendation: .bet, action: .raise(to: 100),
                                       equity: 0.7, potOddsNeeded: nil, street: .flop).verdict, .followed)
        XCTAssertEqual(Reviewer.review(recommendation: .check, action: .checkCall,
                                       equity: nil, potOddsNeeded: nil, street: .preflop).verdict, .followed)
    }

    func testBadCallIsALeak() {
        let r = Reviewer.review(recommendation: .fold, action: .checkCall,
                                equity: 0.18, potOddsNeeded: 0.29, street: .turn)
        XCTAssertEqual(r.verdict, .leak)
        XCTAssertTrue(r.line.contains("18%"))
        XCTAssertTrue(r.line.contains("29%"))
        XCTAssertEqual(r.severity, 0.11, accuracy: 0.001)
    }

    func testFoldingProfitableSpotIsALeak() {
        let r = Reviewer.review(recommendation: .call, action: .fold,
                                equity: 0.40, potOddsNeeded: 0.22, street: .river)
        XCTAssertEqual(r.verdict, .leak)
        XCTAssertEqual(r.severity, 0.18, accuracy: 0.001)
    }

    func testAggressionDeviationsAreAcceptable() {
        XCTAssertEqual(Reviewer.review(recommendation: .call, action: .raise(to: 200),
                                       equity: 0.55, potOddsNeeded: 0.2, street: .flop).verdict, .acceptable)
        XCTAssertEqual(Reviewer.review(recommendation: .raise, action: .checkCall,
                                       equity: 0.6, potOddsNeeded: nil, street: .flop).verdict, .acceptable)
    }

    func testLeaksOutrankAcceptableForLessonPicking() {
        XCTAssertTrue(ReviewVerdict.acceptable < ReviewVerdict.leak)
        XCTAssertTrue(ReviewVerdict.followed < ReviewVerdict.acceptable)
    }
}

final class AdviceNumbersTests: XCTestCase {
    func testPostflopAdviceCarriesNumbers() {
        let advice = Coach.postflopAdvice(
            hole: [Card(13, .spades), Card(13, .hearts)],
            board: [Card(2, .clubs), Card(7, .diamonds), Card(9, .spades)],
            equity: EquityResult(win: 0.7, tie: 0.02),
            toCall: 50, pot: 150, opponents: 1, outs: []
        )
        XCTAssertNotNil(advice.equity)
        XCTAssertEqual(advice.potOddsNeeded ?? 0, 0.25, accuracy: 0.001)
    }

    func testPreflopAdviceCarriesChenScore() {
        let advice = Coach.preflopAdvice(
            hole: [Card(14, .spades), Card(14, .hearts)],
            toCall: 20, bigBlind: 20, position: .button
        )
        XCTAssertEqual(advice.chenScore, 20)
    }
}
