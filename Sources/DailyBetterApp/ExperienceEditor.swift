import SwiftData
import SwiftUI

struct ExperienceEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query private var groups: [ExperienceGroup]
  @Query private var records: [ImprovementRecord]
  @Query private var observations: [RecordObservation]
  let experience: Experience
  @State private var practice: String
  @State private var scenario: String
  @State private var effect: String
  @State private var notes: String
  @State private var group: String
  @State private var maturity: ExperienceMaturity
  @State private var status: ExperienceStatus
  @State private var error: String?
  init(experience: Experience) {
    self.experience = experience
    _practice = State(initialValue: experience.practice)
    _scenario = State(initialValue: experience.scenario)
    _effect = State(initialValue: experience.effect)
    _notes = State(initialValue: experience.notes)
    _group = State(initialValue: experience.groupName)
    _maturity = State(initialValue: experience.maturity)
    _status = State(initialValue: experience.status)
  }
  private var linked: [ImprovementRecord] {
    records.filter { $0.experienceID == experience.id || $0.id == experience.sourceRecordID }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("经验详情与编辑").font(.title2.bold())
      Form {
        TextField("当前做法", text: $practice, axis: .vertical).lineLimit(2...8)
        TextField("适用场景", text: $scenario, axis: .vertical).lineLimit(1...4)
        TextField("观察效果", text: $effect, axis: .vertical).lineLimit(2...6)
        TextField("注意事项", text: $notes, axis: .vertical).lineLimit(1...5)
        Picker("分组", selection: $group) {
          Text("未分组").tag("")
          ForEach(groups.filter { $0.itemID == experience.itemID }) { Text($0.name).tag($0.name) }
        }
        Picker("成熟度", selection: $maturity) {
          ForEach(ExperienceMaturity.allCases) { Text($0.rawValue).tag($0) }
        }
        Picker("有效状态", selection: $status) {
          ForEach(ExperienceStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Section("关联记录与观察") {
          if linked.isEmpty { Text("未关联记录").foregroundStyle(.secondary) }
          ForEach(linked) { record in
            VStack(alignment: .leading, spacing: 6) {
              Text(record.createdAt, format: .dateTime.year().month().day()).foregroundStyle(
                .secondary)
              Text(record.content).textSelection(.enabled)
              ForEach(observations.filter { $0.recordID == record.id }.sorted { $0.date < $1.date })
              { observation in
                Text(
                  "\(observation.date.formatted(date: .abbreviated, time: .omitted)) · \(observation.content)"
                ).textSelection(.enabled)
              }
            }
          }
        }
      }.formStyle(.grouped)
      if let error { Text(error).foregroundStyle(.red) }
      HStack {
        DeleteEntryButton(
          title: "删除经验", summary: experience.practice,
          message: "关联的改进记录和观察内容会保留。"
        ) {
          try EntryDeletion.experience(experience, context: context)
          dismiss()
        }
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("保存修改") { save() }.keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 660, height: 640)
  }
  private func save() {
    guard !practice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      error = "当前做法不能为空。"
      return
    }
    if maturity == .validated && experience.maturity != .validated
      && effect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      error = "请记录实际观察效果，再确认已沉淀。"
      return
    }
    let changed =
      practice != experience.practice || scenario != experience.scenario
      || effect != experience.effect || notes != experience.notes || maturity != experience.maturity
      || status != experience.status
    experience.practice = practice
    experience.scenario = scenario
    experience.effect = effect
    experience.notes = notes
    experience.groupName = group
    experience.maturityRaw = maturity.rawValue
    experience.statusRaw = status.rawValue
    if changed { experience.updatedAt = .now }
    do {
      try context.save()
      dismiss()
    } catch {
      context.rollback()
      self.error = error.localizedDescription
    }
  }
}
