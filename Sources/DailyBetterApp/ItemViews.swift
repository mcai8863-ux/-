import SwiftData
import SwiftUI

struct ItemWorkspace: View {
  let item: Item
  let items: [Item]
  let experiences: [Experience]
  let records: [ImprovementRecord]
  @Binding var showingRecords: Bool
  @State private var editingItem = false
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("视图", selection: $showingRecords) {
          Text("经验库").tag(false)
          Text("改进记录").tag(true)
        }.pickerStyle(.segmented).frame(width: 240)
        Spacer()
        Button("编辑事项") { editingItem = true }
      }.padding(16)
      if showingRecords {
        RecordListView(
          title: item.name + " · 改进记录", records: records.filter { $0.itemID == item.id },
          items: items)
      } else {
        ExperienceLibraryView(title: item.name, item: item, items: items, experiences: experiences)
      }
    }.sheet(isPresented: $editingItem) { ItemEditor(item: item, items: items) }
  }
}

struct ItemEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  let item: Item?
  let items: [Item]
  @State private var name: String
  @State private var goal: String
  @State private var area: LifeArea
  @State private var error: String?
  init(item: Item? = nil, items: [Item]) {
    self.item = item
    self.items = items
    _name = State(initialValue: item?.name ?? "")
    _goal = State(initialValue: item?.goal ?? "")
    _area = State(initialValue: item?.area ?? .life)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(item == nil ? "新增事项" : "编辑事项").font(.title2.bold())
      Form {
        TextField("事项名称", text: $name)
        Picker("分类", selection: $area) { ForEach(LifeArea.allCases) { Text($0.rawValue).tag($0) } }
        TextField("改善目标（选填）", text: $goal)
      }
      if let error { Text(error).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("保存") { save() }.keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 460)
  }
  private func save() {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      error = "请填写事项名称。"
      return
    }
    guard
      !items.contains(where: {
        $0.id != item?.id && $0.area == area
          && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
      })
    else {
      error = "这个分类已有同名事项。"
      return
    }
    let value = item ?? Item(area: area, name: trimmed)
    if item == nil { context.insert(value) }
    value.name = trimmed
    value.areaRaw = area.rawValue
    value.goal = goal
    do {
      try context.save()
      dismiss()
    } catch {
      context.rollback()
      self.error = error.localizedDescription
    }
  }
}
