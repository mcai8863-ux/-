import SwiftData
import SwiftUI

struct RecordListView: View {
  @Environment(\.modelContext) private var context
  let title: String
  let records: [ImprovementRecord]
  let items: [Item]
  @State private var editing: ImprovementRecord?
  @State private var selection: UUID?
  @State private var query = ""

  private var filtered: [ImprovementRecord] {
    records.filter { query.isEmpty || $0.content.localizedCaseInsensitiveContains(query) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title).font(.title2.bold())
        Text("\(filtered.count) 条").foregroundStyle(.secondary)
        Spacer()
        Button("编辑 / 补结果") { openSelected() }.disabled(selection == nil)
        if let record = filtered.first(where: { $0.id == selection }) {
          DeleteEntryButton(
            title: "删除记录", summary: record.content,
            message: "该记录的观察内容也会删除；关联经验和扭蛋采纳状态会保留。"
          ) {
            try EntryDeletion.record(record, context: context)
            selection = nil
          }
        }
        TextField("搜索记录", text: $query).frame(width: 220)
      }.padding(.horizontal, 20).padding(.top, 16)
      if filtered.isEmpty {
        ContentUnavailableView(
          "暂无记录", systemImage: "square.and.pencil", description: Text("点击随手记，记录一个想法或一次尝试。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(filtered, selection: $selection) {
          TableColumn("日期") { record in
            Text(record.createdAt, format: .dateTime.year().month().day())
          }.width(100)
          TableColumn("本次调整") { record in Text(record.content).lineLimit(2) }.width(min: 240)
          TableColumn("类型") { record in Text(record.kind.rawValue) }.width(80)
          TableColumn("判断") { record in Text(record.kind == .tried ? record.judgmentRaw : "—") }
            .width(80)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
          Button("编辑 / 补结果") { editing = filtered.first { ids.contains($0.id) } }
        } primaryAction: { ids in
          editing = filtered.first { ids.contains($0.id) }
        }
        .onKeyPress(.return) {
          openSelected()
          return .handled
        }
      }
    }
    .sheet(item: $editing) { RecordEditor(record: $0, items: items) }
  }

  private func openSelected() { editing = filtered.first { $0.id == selection } }
}

struct RecordEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Query private var observations: [RecordObservation]
  @Query private var experiences: [Experience]
  let record: ImprovementRecord
  let items: [Item]
  @State private var content: String
  @State private var itemID: UUID?
  @State private var kind: RecordKind
  @State private var date: Date
  @State private var judgment: String
  @State private var observation = ""
  @State private var observationDate = Date.now
  @State private var targetID: UUID?
  @State private var error: String?

  init(record: ImprovementRecord, items: [Item]) {
    self.record = record
    self.items = items
    _content = State(initialValue: record.content)
    _itemID = State(initialValue: record.itemID)
    _kind = State(initialValue: record.kind)
    _date = State(initialValue: record.createdAt)
    _judgment = State(initialValue: record.judgmentRaw)
    _targetID = State(initialValue: record.experienceID)
  }

  private var history: [RecordObservation] {
    observations.filter { $0.recordID == record.id }.sorted { $0.date > $1.date }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("记录与观察").font(.title2.bold())
      Form {
        TextField("本次调整", text: $content, axis: .vertical).lineLimit(2...6)
        DatePicker("发生日期", selection: $date, displayedComponents: .date)
        Picker("归入事项", selection: $itemID) {
          Text("待整理").tag(nil as UUID?)
          ForEach(items) { Text($0.name).tag($0.id as UUID?) }
        }.disabled(
          record.experienceID != nil || experiences.contains { $0.sourceRecordID == record.id })
        Picker("类型", selection: $kind) {
          ForEach(RecordKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        if kind == .tried {
          Picker("判断", selection: $judgment) {
            ForEach(["待观察", "保留", "不采用"], id: \.self) { Text($0).tag($0) }
          }
        }
        Section("追加观察") {
          TextField("这次尝试有什么结果？", text: $observation, axis: .vertical).lineLimit(2...4)
          DatePicker("观察日期", selection: $observationDate, displayedComponents: .date)
        }
        Section("已有观察") {
          if history.isEmpty { Text("尚未记录观察结果").foregroundStyle(.secondary) }
          ForEach(history) { entry in
            VStack(alignment: .leading) {
              Text(entry.date, format: .dateTime.year().month().day()).foregroundStyle(.secondary)
              Text(entry.content).textSelection(.enabled)
            }
          }
        }
        if itemID != nil {
          Picker("沉淀到", selection: $targetID) {
            Text("新建经验（已有来源条目时更新它）").tag(nil as UUID?)
            ForEach(experiences.filter { $0.itemID == itemID }) {
              Text($0.practice).tag($0.id as UUID?)
            }
          }
        }
      }.formStyle(.grouped)
      if let error { Text(error).foregroundStyle(.red) }
      HStack {
        Button("取消", role: .cancel) { dismiss() }
        DeleteEntryButton(
          title: "删除记录", summary: record.content,
          message: "该记录的观察内容也会删除；关联经验和扭蛋采纳状态会保留。"
        ) {
          try EntryDeletion.record(record, context: context)
          dismiss()
        }
        Spacer()
        Button("保存记录") { save(promote: false) }
        Button("确认有效并沉淀") { save(promote: true) }
          .buttonStyle(.borderedProminent)
          .disabled(itemID == nil || kind != .tried || judgment != "保留")
      }
    }.padding(24).frame(width: 660, height: 650)
  }

  private func save(promote: Bool) {
    do {
      try RecordWorkflow.save(
        record: record, content: content, itemID: itemID, kind: kind, date: date,
        judgment: judgment, observation: observation, observationDate: observationDate,
        promote: promote, targetID: targetID, context: context)
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}
