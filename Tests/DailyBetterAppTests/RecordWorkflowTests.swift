import SwiftData
import XCTest

@testable import DailyBetterApp

final class RecordWorkflowTests: XCTestCase {
  @MainActor private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: ImprovementRecord.self, Experience.self, RecordObservation.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
  }
  @MainActor func testObservationAndPromotionReuseExperience() throws {
    let context = try makeContext()
    let itemID = UUID()
    let record = ImprovementRecord(itemID: itemID, content: "先写结论", kind: .idea)
    context.insert(record)
    let experience = Experience(
      itemID: itemID, practice: record.content, maturity: .pending, sourceRecordID: record.id)
    context.insert(experience)
    try context.save()
    for result in ["汇报缩短了五分钟", "再次尝试同样有效"] {
      try RecordWorkflow.save(
        record: record, content: record.content, itemID: itemID, kind: .tried,
        date: record.createdAt,
        judgment: "保留", observation: result, observationDate: .now, promote: true, targetID: nil,
        context: context)
    }
    XCTAssertEqual(try context.fetch(FetchDescriptor<Experience>()).count, 1)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RecordObservation>()).count, 2)
    XCTAssertEqual(experience.maturity, .validated)
    XCTAssertEqual(record.experienceID, experience.id)
  }
  @MainActor func testPromotionNeedsEvidenceAndCannotCrossItems() throws {
    let context = try makeContext()
    let record = ImprovementRecord(itemID: UUID(), content: "尝试")
    context.insert(record)
    try context.save()
    XCTAssertThrowsError(
      try RecordWorkflow.save(
        record: record, content: "改写", itemID: record.itemID, kind: .tried,
        date: .now, judgment: "保留", observation: "", observationDate: .now, promote: true,
        targetID: nil, context: context))
    XCTAssertEqual(record.content, "尝试")
    let other = Experience(itemID: UUID(), practice: "另一事项")
    context.insert(other)
    try context.save()
    XCTAssertThrowsError(
      try RecordWorkflow.save(
        record: record, content: record.content, itemID: record.itemID, kind: .tried,
        date: .now, judgment: "保留", observation: "有效", observationDate: .now, promote: true,
        targetID: other.id, context: context))
    XCTAssertEqual(try context.fetch(FetchDescriptor<RecordObservation>()).count, 0)
  }
  @MainActor func testInboxAssignmentPreservesOriginalDate() throws {
    let context = try makeContext()
    let date = Date(timeIntervalSince1970: 100)
    let record = ImprovementRecord(content: "想到就记", createdAt: date)
    context.insert(record)
    try context.save()
    let itemID = UUID()
    try RecordWorkflow.save(
      record: record, content: record.content, itemID: itemID, kind: .idea, date: date,
      judgment: "待观察", observation: "", observationDate: .now, promote: false, targetID: nil,
      context: context)
    XCTAssertEqual(record.itemID, itemID)
    XCTAssertEqual(record.createdAt, date)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Experience>()).count, 0)
  }
}
