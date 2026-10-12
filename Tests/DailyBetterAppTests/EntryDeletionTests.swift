import SwiftData
import XCTest

@testable import DailyBetterApp

final class EntryDeletionTests: XCTestCase {
  @MainActor private func context() throws -> ModelContext {
    let container = try ModelContainer(
      for: Experience.self, ImprovementRecord.self, RecordObservation.self,
      InspirationDecision.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ModelContext(container)
  }

  @MainActor func testDeletingExperiencePreservesRecordAndPreventsRecreation() throws {
    let context = try context()
    let record = ImprovementRecord(itemID: UUID(), content: "想法", kind: .idea)
    let experience = Experience(itemID: record.itemID!, practice: "做法", sourceRecordID: record.id)
    record.experienceID = experience.id
    let observation = RecordObservation(recordID: record.id, content: "有效", date: .now)
    context.insert(record)
    context.insert(experience)
    context.insert(observation)
    try context.save()
    try EntryDeletion.experience(experience, context: context)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Experience>()).count, 0)
    XCTAssertEqual(try context.fetch(FetchDescriptor<ImprovementRecord>()).count, 1)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RecordObservation>()).count, 1)
    XCTAssertNil(record.experienceID)
    XCTAssertTrue(record.preventAutomaticExperience)
  }

  @MainActor func testDeletingRecordPreservesExperienceAndDecisionAndOtherObservations() throws {
    let context = try context()
    let record = ImprovementRecord(content: "记录")
    let other = ImprovementRecord(content: "另一条记录")
    let experience = Experience(itemID: UUID(), practice: "经验", sourceRecordID: record.id)
    let decision = InspirationDecision(cardID: "test", status: .adopted, recordID: record.id)
    context.insert(record)
    context.insert(other)
    context.insert(experience)
    context.insert(decision)
    context.insert(RecordObservation(recordID: record.id, content: "结果", date: .now))
    context.insert(RecordObservation(recordID: other.id, content: "保留", date: .now))
    try context.save()
    try EntryDeletion.record(record, context: context)
    XCTAssertEqual(try context.fetch(FetchDescriptor<ImprovementRecord>()).map(\.id), [other.id])
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<RecordObservation>()).map(\.recordID), [other.id])
    XCTAssertEqual(try context.fetch(FetchDescriptor<Experience>()).count, 1)
    XCTAssertNil(experience.sourceRecordID)
    XCTAssertNil(decision.recordID)
    XCTAssertEqual(decision.statusRaw, InspirationDecisionStatus.adopted.rawValue)
  }
}
