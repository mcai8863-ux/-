import SwiftData
import SwiftUI

struct QuickCaptureView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let items: [Item]
  let preselectedItem: Item?
  var onSaved: (UUID?) -> Void = { _ in }

  @AppStorage("quickCaptureDraft") private var content = ""
  @State private var error: String?
  @State private var selectedItemID: UUID?
  @FocusState private var contentFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("随手记").font(.title.bold())
      TextEditor(text: $content)
        .font(.body)
        .frame(minHeight: 150)
        .padding(8)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
        .focused($contentFocused)
        .accessibilityLabel("记录内容")
      Picker("归入事项", selection: $selectedItemID) {
        Text("暂不分类").tag(nil as UUID?)
        ForEach(items) { item in Text("\(item.area.rawValue) · \(item.name)").tag(item.id as UUID?)
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("保存") { save() }
          .keyboardShortcut(.defaultAction)
          .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .frame(width: 520)
    .onAppear {
      selectedItemID = preselectedItem?.id
      contentFocused = true
    }
  }

  private func save() {
    modelContext.insert(
      ImprovementRecord(
        itemID: selectedItemID, content: content.trimmingCharacters(in: .whitespacesAndNewlines)))
    do {
      try modelContext.save()
      content = ""
      dismiss()
      onSaved(selectedItemID)
    } catch {
      modelContext.rollback()
      self.error = error.localizedDescription
    }
  }
}

struct NewExperienceView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExperienceGroup.sortOrder) private var allGroups: [ExperienceGroup]
  let item: Item

  @State private var practice = ""
  @State private var group = ""
  @State private var scenario = ""
  @State private var effect = ""
  @State private var notes = ""
  @State private var maturity: ExperienceMaturity = .pending

  private var groups: [ExperienceGroup] {
    allGroups.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("新增经验").font(.title.bold())
      Text(item.name).foregroundStyle(.secondary)
      Form {
        TextField("当前做法", text: $practice, axis: .vertical).lineLimit(2...5)
        Picker("分组", selection: $group) {
          Text("未分组").tag("")
          ForEach(groups) { value in Text(value.name).tag(value.name) }
        }
        Picker("成熟度", selection: $maturity) {
          ForEach(ExperienceMaturity.allCases) { value in Text(value.rawValue).tag(value) }
        }
        TextField("适用场景", text: $scenario, axis: .vertical).lineLimit(1...3)
        TextField("观察效果", text: $effect, axis: .vertical).lineLimit(1...3)
        TextField("注意事项", text: $notes, axis: .vertical).lineLimit(1...3)
      }
      .formStyle(.grouped)
      HStack {
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("保存经验") { save() }
          .keyboardShortcut(.defaultAction)
          .disabled(practice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .frame(width: 600)
  }

  private func save() {
    modelContext.insert(
      Experience(
        itemID: item.id, groupName: group, practice: practice, scenario: scenario, effect: effect,
        notes: notes, maturity: maturity))
    try? modelContext.save()
    dismiss()
  }
}
