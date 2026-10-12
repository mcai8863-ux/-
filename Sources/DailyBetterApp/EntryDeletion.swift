import SwiftData
import SwiftUI

@MainActor
enum EntryDeletion {
  static func experience(_ experience: Experience, context: ModelContext) throws {
    let records = try context.fetch(FetchDescriptor<ImprovementRecord>())
    do {
      for record in records
      where record.experienceID == experience.id || record.id == experience.sourceRecordID {
        if record.experienceID == experience.id { record.experienceID = nil }
        record.preventAutomaticExperience = true
      }
      context.delete(experience)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  static func record(_ record: ImprovementRecord, context: ModelContext) throws {
    let experiences = try context.fetch(FetchDescriptor<Experience>())
    let observations = try context.fetch(FetchDescriptor<RecordObservation>())
    let decisions = try context.fetch(FetchDescriptor<InspirationDecision>())
    do {
      for experience in experiences where experience.sourceRecordID == record.id {
        experience.sourceRecordID = nil
      }
      for decision in decisions where decision.recordID == record.id {
        decision.recordID = nil
      }
      for observation in observations where observation.recordID == record.id {
        context.delete(observation)
      }
      context.delete(record)
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }
}

struct DeleteEntryButton: View {
  let title: String
  let summary: String
  let message: String
  let action: () throws -> Void
  @State private var confirming = false
  @State private var error: String?

  var body: some View {
    Button(title, systemImage: "trash", role: .destructive) { confirming = true }
      .confirmationDialog(title + "？", isPresented: $confirming, titleVisibility: .visible) {
        Button("删除", role: .destructive) {
          do { try action() } catch { self.error = error.localizedDescription }
        }
        Button("取消", role: .cancel) {}
      } message: {
        Text("“\(summary.prefix(80))”\n\(message)\n删除后无法恢复。")
      }
      .alert(
        "删除失败",
        isPresented: Binding(
          get: { error != nil }, set: { if !$0 { error = nil } }
        )
      ) {
        Button("好", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
  }
}
