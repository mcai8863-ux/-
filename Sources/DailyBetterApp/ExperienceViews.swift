import SwiftData
import SwiftUI

struct ExperienceLibraryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExperienceGroup.sortOrder) private var allGroups: [ExperienceGroup]
  let title: String
  let item: Item?
  let items: [Item]
  let experiences: [Experience]

  @State private var query = ""
  @State private var editing: Experience?
  @State private var rowSelection: UUID?
  @State private var selectedStatus: ExperienceStatus? = .current
  @State private var selectedGroup: String?
  @State private var selectedMaturity: ExperienceMaturity?
  @State private var showingGroupPicker = false
  @State private var showingGroupManager = false
  @State private var showingExporter = false
  @State private var exportDocument = CSVDocument(content: "")
  @State private var exportMessage: String?
  @State private var selectedArea: LifeArea?
  @State private var newExperienceItem: Item?
  @State private var showingItemPicker = false

  private let accent = Color(red: 0.10, green: 0.39, blue: 0.31)

  private var scoped: [Experience] {
    guard let item else { return experiences }
    return experiences.filter { $0.itemID == item.id }
  }

  private var groups: [String] {
    guard let item else { return [] }
    return allGroups.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }.map(
      \.name)
  }

  private var matchingScope: [Experience] {
    scoped.filter { experience in
      let groupMatches = selectedGroup == nil || experience.groupName == selectedGroup
      let areaMatches =
        selectedArea == nil
        || items.first(where: { $0.id == experience.itemID })?.area == selectedArea
      let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
      let searchMatches =
        needle.isEmpty
        || [experience.practice, experience.scenario, experience.effect, experience.notes]
          .contains { $0.localizedCaseInsensitiveContains(needle) }
      return groupMatches && areaMatches && searchMatches
        && (selectedStatus == nil || experience.status == selectedStatus)
    }
  }

  private var filtered: [Experience] {
    matchingScope.filter { selectedMaturity == nil || $0.maturity == selectedMaturity }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if filtered.isEmpty {
        ContentUnavailableView.search(text: query)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        experienceTable
      }
      HStack {
        Text("显示 \(filtered.count) 条，共 \(scoped.count) 条")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text("紧凑视图").font(.caption).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 28).padding(.vertical, 14)
    }
    .background(.background)
    .navigationTitle(title)
    .sheet(item: $editing) { ExperienceEditor(experience: $0) }
    .sheet(item: $newExperienceItem) { NewExperienceView(item: $0) }
    .sheet(isPresented: $showingGroupManager) {
      if let item {
        GroupManagerView(item: item, experiences: scoped)
      }
    }
    .fileExporter(
      isPresented: $showingExporter,
      document: exportDocument,
      contentType: .commaSeparatedText,
      defaultFilename: exportFilename
    ) { result in
      if case .failure(let error) = result { exportMessage = error.localizedDescription }
    }
    .alert(
      "导出失败",
      isPresented: Binding(get: { exportMessage != nil }, set: { if !$0 { exportMessage = nil } })
    ) {
      Button("好") { exportMessage = nil }
    } message: {
      Text(exportMessage ?? "未知错误")
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .firstTextBaseline) {
        Text(title).font(.largeTitle.bold())
        Text(item == nil ? "把有效的方法，留给下一次。" : "\(scoped.count) 条经验")
          .font(.callout).foregroundStyle(.secondary)
        Spacer()
        Button("导出 CSV", systemImage: "square.and.arrow.up") { prepareExport() }
          .controlSize(.large)
        Button("新增经验", systemImage: "plus") {
          if let item { newExperienceItem = item } else { showingItemPicker = true }
        }
        .buttonStyle(.borderedProminent).tint(accent).controlSize(.large)
        .disabled(items.isEmpty)
        .popover(isPresented: $showingItemPicker) {
          VStack(alignment: .leading, spacing: 12) {
            Text("选择所属事项").font(.headline)
            ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { value in
                  Button("\(value.area.rawValue) · \(value.name)") {
                    showingItemPicker = false
                    newExperienceItem = value
                  }.buttonStyle(.plain)
                }
              }
            }
          }.padding(18).frame(width: 240, height: 280)
        }
      }
      HStack(spacing: 20) {
        maturityTab(nil)
        maturityTab(.validated)
        maturityTab(.testing)
        maturityTab(.pending)
        Spacer(minLength: 8)
        if item == nil {
          Picker("分类", selection: $selectedArea) {
            Text("全部分类").tag(nil as LifeArea?)
            ForEach(LifeArea.allCases) { Text($0.rawValue).tag($0 as LifeArea?) }
          }.labelsHidden().frame(width: 110)
        }
        TextField("搜索做法、场景、效果", text: $query)
          .textFieldStyle(.roundedBorder).frame(minWidth: 180, idealWidth: 240, maxWidth: 300)
      }
      HStack {
        if item != nil {
          Button {
            showingGroupPicker.toggle()
          } label: {
            Label(selectedGroup ?? "全部分组", systemImage: "line.3.horizontal.decrease.circle")
          }
          .popover(isPresented: $showingGroupPicker, arrowEdge: .bottom) {
            GroupPicker(groups: groups, selection: $selectedGroup)
          }
          if selectedGroup != nil {
            Button("清除分组", systemImage: "xmark.circle.fill") { selectedGroup = nil }
              .labelStyle(.iconOnly)
              .accessibilityLabel("清除分组筛选")
          }
          if item != nil {
            Button("管理分组", systemImage: "folder.badge.gearshape") { showingGroupManager = true }
          }
        }
        Picker("有效状态", selection: $selectedStatus) {
          Text("全部状态").tag(nil as ExperienceStatus?)
          ForEach(ExperienceStatus.allCases, id: \.self) {
            Text($0.rawValue).tag($0 as ExperienceStatus?)
          }
        }.labelsHidden().frame(width: 120)
        Spacer()
        if rowSelection != nil {
          Button("查看 / 编辑") { editing = filtered.first { $0.id == rowSelection } }
          if let experience = filtered.first(where: { $0.id == rowSelection }) {
            DeleteEntryButton(
              title: "删除经验", summary: experience.practice,
              message: "关联的改进记录和观察内容会保留。"
            ) {
              try EntryDeletion.experience(experience, context: modelContext)
              rowSelection = nil
            }
          }
        }
      }
    }
    .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 16)
  }

  private func maturityTab(_ value: ExperienceMaturity?) -> some View {
    let selected = selectedMaturity == value
    let count = matchingScope.filter { value == nil || $0.maturity == value }.count
    return Button {
      selectedMaturity = value
      rowSelection = nil
    } label: {
      HStack(spacing: 6) {
        Text(value?.rawValue ?? "全部")
        Text("\(count)").monospacedDigit()
      }
      .font(.callout.weight(selected ? .semibold : .regular))
      .foregroundStyle(selected ? accent : .secondary)
      .padding(.vertical, 10)
      .overlay(alignment: .bottom) {
        if selected { Capsule().fill(accent).frame(height: 3) }
      }
    }.buttonStyle(.plain)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var experienceTable: some View {
    Table(filtered, selection: $rowSelection) {
      TableColumn("所属事项") { value in Text(items.first { $0.id == value.itemID }?.name ?? "未知事项") }
        .width(min: 85, ideal: 110)
      TableColumn("当前做法") { value in Text(value.practice).fontWeight(.medium).lineLimit(2) }.width(
        min: 220, ideal: 320)
      TableColumn("适用场景") { value in Text(value.scenario).lineLimit(2) }.width(min: 120, ideal: 170)
      TableColumn("观察效果") { value in Text(value.effect).lineLimit(2) }.width(min: 160, ideal: 220)
      TableColumn("成熟度") { value in
        Button {
          editing = value
        } label: {
          Label(value.maturity.rawValue, systemImage: value.maturity.symbol)
            .foregroundStyle(maturityColor(value.maturity))
        }.buttonStyle(.plain).help("查看详情并修改成熟度")
      }.width(min: 95, ideal: 110)
      TableColumn("最近调整") { value in Text(value.updatedAt, format: .dateTime.month().day()) }.width(
        90)
    }
    .tableStyle(.inset(alternatesRowBackgrounds: false))
    .scrollContentBackground(.hidden)
    .background(accent.opacity(0.025))
    .clipShape(.rect(cornerRadius: 6))
    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(accent.opacity(0.15)) }
    .padding(.horizontal, 28)
    .contextMenu(forSelectionType: UUID.self) { ids in
      Button("查看 / 编辑") { editing = filtered.first { ids.contains($0.id) } }
    } primaryAction: { ids in
      editing = filtered.first { ids.contains($0.id) }
    }
    .onKeyPress(.return) {
      editing = filtered.first { $0.id == rowSelection }
      return .handled
    }
  }

  private var exportFilename: String {
    "日进-\(item?.name ?? "全部经验")-\(Date.now.formatted(.iso8601.year().month().day()))"
  }

  private func prepareExport() {
    let names = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
    let rows = filtered.map {
      ExperienceExportRow(
        item: names[$0.itemID] ?? "未知事项", group: $0.groupName, practice: $0.practice,
        scenario: $0.scenario, effect: $0.effect, notes: $0.notes, status: $0.maturity.rawValue,
        updatedAt: $0.updatedAt)
    }
    exportDocument = CSVDocument(content: CSVEncoder.encode(rows: rows))
    showingExporter = true
  }

  private func maturityColor(_ maturity: ExperienceMaturity) -> Color {
    switch maturity {
    case .pending: .orange
    case .testing: .blue
    case .validated: .green
    }
  }
}

private struct GroupManagerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \ExperienceGroup.sortOrder) private var allGroups: [ExperienceGroup]
  let item: Item
  let experiences: [Experience]

  @State private var newName = ""
  @State private var errorMessage: String?

  private var groups: [ExperienceGroup] {
    allGroups.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("管理分组").font(.title2.bold())
          Text(item.name).foregroundStyle(.secondary)
        }
        Spacer()
        Button("完成") { saveAndDismiss() }
      }

      HStack {
        TextField("新分组名称", text: $newName)
          .onSubmit(addGroup)
        Button("新增", action: addGroup)
          .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if let errorMessage {
        Text(errorMessage).font(.caption).foregroundStyle(.red)
      }

      if groups.isEmpty {
        ContentUnavailableView(
          "还没有分组", systemImage: "folder.badge.plus", description: Text("新增后，可在经验中选择这些分组。"))
      } else {
        List(groups) { group in
          HStack {
            TextField(
              "分组名称",
              text: Binding(
                get: { group.name },
                set: { rename(group, to: $0) }
              ))
            Text("\(experiences.filter { $0.groupName == group.name }.count) 条")
              .font(.caption).foregroundStyle(.secondary)
            Button("删除", systemImage: "trash", role: .destructive) { delete(group) }
              .labelStyle(.iconOnly)
              .accessibilityLabel("删除分组 \(group.name)")
          }
        }
      }
    }
    .padding(22)
    .frame(width: 500, height: 440)
  }

  private func addGroup() {
    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    guard !groups.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame })
    else {
      errorMessage = "已有同名分组。"
      return
    }
    modelContext.insert(ExperienceGroup(itemID: item.id, name: name, sortOrder: groups.count))
    try? modelContext.save()
    newName = ""
    errorMessage = nil
  }

  private func rename(_ group: ExperienceGroup, to value: String) {
    let oldName = group.name
    group.name = value
    for experience in experiences where experience.groupName == oldName {
      experience.groupName = value
    }
  }

  private func delete(_ group: ExperienceGroup) {
    for experience in experiences where experience.groupName == group.name {
      experience.groupName = ""
    }
    modelContext.delete(group)
    try? modelContext.save()
  }

  private func saveAndDismiss() {
    let normalized = groups.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard normalized.allSatisfy({ !$0.isEmpty }),
      Set(normalized.map { $0.lowercased() }).count == normalized.count
    else {
      errorMessage = "分组名称不能为空或重复。"
      return
    }
    for (index, group) in groups.enumerated() {
      let trimmed = normalized[index]
      if group.name != trimmed {
        let oldName = group.name
        group.name = trimmed
        for experience in experiences where experience.groupName == oldName {
          experience.groupName = trimmed
        }
      }
    }
    try? modelContext.save()
    dismiss()
  }
}

private struct GroupPicker: View {
  let groups: [String]
  @Binding var selection: String?
  @State private var search = ""

  private var filteredGroups: [String] {
    search.isEmpty ? groups : groups.filter { $0.localizedCaseInsensitiveContains(search) }
  }

  var body: some View {
    VStack(spacing: 8) {
      TextField("搜索分组", text: $search).textFieldStyle(.roundedBorder)
      List {
        Button {
          selection = nil
        } label: {
          Label("全部分组", systemImage: selection == nil ? "checkmark" : "")
        }
        ForEach(filteredGroups, id: \.self) { group in
          Button {
            selection = group
          } label: {
            Label(group, systemImage: selection == group ? "checkmark" : "")
          }
        }
      }
      .buttonStyle(.plain)
    }
    .padding(12)
    .frame(width: 280, height: 320)
  }
}
