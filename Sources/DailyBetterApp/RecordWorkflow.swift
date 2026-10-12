import Foundation
import SwiftData

@Model
final class RecordObservation {
  @Attribute(.unique) var id: UUID
  var recordID: UUID
  var content: String
  var date: Date
  init(recordID: UUID, content: String, date: Date) {
    self.id = UUID()
    self.recordID = recordID
    self.content = content
    self.date = date
  }
}

enum WorkflowError: LocalizedError {
  case invalid(String)
  var errorDescription: String? { if case .invalid(let message) = self { message } else { nil } }
}

@MainActor
enum RecordWorkflow {
  static func save(
    record: ImprovementRecord, content: String, itemID: UUID?, kind: RecordKind,
    date: Date, judgment: String, observation: String, observationDate: Date,
    promote: Bool, targetID: UUID?, context: ModelContext
  ) throws {
    let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
    let result = observation.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw WorkflowError.invalid("请填写本次调整。") }
    let experiences = try context.fetch(FetchDescriptor<Experience>())
    let existing =
      experiences.first { $0.id == (targetID ?? record.experienceID) }
      ?? experiences.first { $0.sourceRecordID == record.id }
    if let existing, existing.itemID != itemID { throw WorkflowError.invalid("已关联经验的记录不能移到其他事项。") }
    let history = try context.fetch(FetchDescriptor<RecordObservation>()).filter {
      $0.recordID == record.id
    }
    if promote {
      guard itemID != nil, kind == .tried, judgment == "保留" else {
        throw WorkflowError.invalid("请先选择事项，并标记为已尝试、保留。")
      }
      guard !result.isEmpty || !history.isEmpty else {
        throw WorkflowError.invalid("请补充至少一条实际观察结果，再确认沉淀。")
      }
    }
    do {
      record.content = text
      record.itemID = itemID
      record.kindRaw = kind.rawValue
      record.createdAt = date
      record.judgmentRaw = kind == .tried ? judgment : "待观察"
      if !result.isEmpty {
        context.insert(
          RecordObservation(recordID: record.id, content: result, date: observationDate))
      }
      if promote, let itemID {
        let experience =
          existing
          ?? Experience(
            itemID: itemID, practice: text, maturity: .pending, sourceRecordID: record.id)
        if existing == nil { context.insert(experience) }
        // Updating an existing conclusion is explicit; preserve its wording while adding evidence.
        let evidence = result.isEmpty ? history.sorted { $0.date > $1.date }.first!.content : result
        experience.effect =
          experience.effect.isEmpty ? evidence : experience.effect + "\n" + evidence
        experience.maturity = .validated
        record.experienceID = experience.id
      }
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }
}
