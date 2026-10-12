import XCTest

@testable import DailyBetterApp

final class InspirationEngineTests: XCTestCase {
  private let cards = [
    InspirationCard(
      id: "LIFE-001", category: "生活", topic: "准备", action: "准备水杯", editorialStatus: "candidate"),
    InspirationCard(
      id: "WORK-001", category: "工作", topic: "沟通", action: "先写结论", editorialStatus: "candidate"),
    InspirationCard(
      id: "LEARN-001", category: "学习", topic: "回忆", action: "合上材料复述", editorialStatus: "candidate"),
  ]

  func testFiltersByAreaAndDecisions() {
    XCTAssertEqual(
      InspirationEngine.availableInRound(cards: cards, decidedIDs: [], seenIDs: [], area: .work)
        .map(\.id), ["WORK-001"])
    XCTAssertEqual(
      InspirationEngine.availableInRound(
        cards: cards, decidedIDs: ["WORK-001"], seenIDs: [], area: nil
      ).map(\.id), ["LIFE-001", "LEARN-001"])
  }

  func testViewingDoesNotDecideButRemovesCardFromCurrentRound() {
    let firstRound = InspirationEngine.availableInRound(
      cards: cards, decidedIDs: [], seenIDs: ["LIFE-001"], area: nil)
    XCTAssertEqual(firstRound.map(\.id), ["WORK-001", "LEARN-001"])

    let nextRound = InspirationEngine.availableInRound(
      cards: cards, decidedIDs: [], seenIDs: [], area: nil)
    XCTAssertEqual(nextRound.count, 3)
  }
}
