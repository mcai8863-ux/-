import SwiftData
import SwiftUI

enum AppDestination: Hashable {
  case allExperiences
  case inbox
  case inspiration
  case item(UUID)
}

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Item.createdAt) private var items: [Item]
  @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
  @Query(sort: \ImprovementRecord.createdAt, order: .reverse) private var records:
    [ImprovementRecord]

  @State private var selection: AppDestination? = .allExperiences
  @State private var showingNewItem = false
  @State private var showingQuickCapture = false
  @State private var showingNewExperience = false
  @State private var sidebarVisible = true
  @State private var showingItemRecords = false

  private let sidebarColor = Color(red: 0.157, green: 0.345, blue: 0.322)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        if sidebarVisible {
          sidebarColor.frame(width: 200)
        }
        HStack(spacing: 12) {
          Button("显示或隐藏侧栏", systemImage: "sidebar.left") { sidebarVisible.toggle() }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .accessibilityLabel(sidebarVisible ? "隐藏侧栏" : "显示侧栏")
          Spacer()
          Button("随手记", systemImage: "plus") { showingQuickCapture = true }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.leading, 14)
        .padding(.trailing, 18)
        .background(.background)
      }
      .frame(height: 52)
      .overlay(alignment: .bottom) { Divider() }

      HStack(spacing: 0) {
        if sidebarVisible {
          SidebarView(
            items: items, records: records, selection: $selection,
            onNewItem: { showingNewItem = true }
          )
          .frame(width: 200)
        }
        destinationView
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
    .ignoresSafeArea(.container, edges: .top)
    .sheet(isPresented: $showingQuickCapture) {
      QuickCaptureView(items: items, preselectedItem: selectedItem) { itemID in
        if let itemID {
          showingItemRecords = true
          selection = .item(itemID)
        } else {
          selection = .inbox
        }
      }
    }
    .sheet(isPresented: $showingNewExperience) {
      if let selectedItem { NewExperienceView(item: selectedItem) }
    }
    .sheet(isPresented: $showingNewItem) { ItemEditor(items: items) }
    .task { seedIfNeeded() }
  }

  @ViewBuilder
  private var destinationView: some View {
    switch selection ?? .allExperiences {
    case .allExperiences:
      ExperienceLibraryView(title: "全部经验", item: nil, items: items, experiences: experiences)
    case .inbox:
      RecordListView(title: "待整理", records: records.filter { $0.itemID == nil }, items: items)
    case .inspiration:
      InspirationView(items: items)
    case .item(let id):
      if let item = items.first(where: { $0.id == id }) {
        ItemWorkspace(
          item: item, items: items, experiences: experiences, records: records,
          showingRecords: $showingItemRecords
        ).id(
          item.id)
      } else {
        ContentUnavailableView("事项不存在", systemImage: "tray")
      }
    }
  }

  private var selectedItem: Item? {
    guard case .item(let id) = selection else { return nil }
    return items.first { $0.id == id }
  }

  private func seedIfNeeded() {
    if items.isEmpty {
      let breakfast = Item(area: .life, name: "早饭", goal: "更省时、更稳定")
      let slides = Item(area: .work, name: "写 PPT", goal: "先讲清楚，再做美观")
      let reading = Item(area: .learning, name: "阅读", goal: "提高理解和复用")
      [breakfast, slides, reading].forEach(modelContext.insert)
      modelContext.insert(ExperienceGroup(itemID: breakfast.id, name: "准备"))
      modelContext.insert(ExperienceGroup(itemID: slides.id, name: "观点与结构"))
      modelContext.insert(ExperienceGroup(itemID: reading.id, name: "主动回忆"))
      modelContext.insert(
        Experience(
          itemID: breakfast.id, groupName: "准备", practice: "前一晚准备第二天早餐食材", scenario: "工作日早晨",
          effect: "减少临时决定，出门更从容"))
      modelContext.insert(
        Experience(
          itemID: slides.id, groupName: "观点与结构", practice: "先写结论，再列支撑结论的三级大纲", scenario: "决策型汇报",
          effect: "减少返工，听众更快理解重点"))
      modelContext.insert(
        Experience(
          itemID: reading.id, groupName: "主动回忆", practice: "读完一节后合上材料写下三个要点", scenario: "学习新概念",
          effect: "更容易发现理解空白"))
    }
    migrateLegacyGroups()
    migrateAdoptedIdeas()
    try? modelContext.save()
  }

  private func migrateLegacyGroups() {
    let storedGroups = (try? modelContext.fetch(FetchDescriptor<ExperienceGroup>())) ?? []
    let storedExperiences = (try? modelContext.fetch(FetchDescriptor<Experience>())) ?? []
    var keys = Set(storedGroups.map { "\($0.itemID.uuidString)|\($0.name)" })
    var nextOrder = Dictionary(grouping: storedGroups, by: \.itemID).mapValues(\.count)
    for experience in storedExperiences where !experience.groupName.isEmpty {
      let key = "\(experience.itemID.uuidString)|\(experience.groupName)"
      if !keys.contains(key) {
        let order = nextOrder[experience.itemID, default: 0]
        modelContext.insert(
          ExperienceGroup(itemID: experience.itemID, name: experience.groupName, sortOrder: order))
        keys.insert(key)
        nextOrder[experience.itemID] = order + 1
      }
    }
  }

  private func migrateAdoptedIdeas() {
    let storedExperiences = (try? modelContext.fetch(FetchDescriptor<Experience>())) ?? []
    let migratedRecordIDs = Set(storedExperiences.compactMap(\.sourceRecordID))
    let storedRecords = (try? modelContext.fetch(FetchDescriptor<ImprovementRecord>())) ?? []
    for record in storedRecords
    where record.kind == .idea && record.experienceID == nil && record.itemID != nil
      && !record.preventAutomaticExperience && !migratedRecordIDs.contains(record.id)
    {
      guard let itemID = record.itemID else { continue }
      modelContext.insert(
        Experience(
          itemID: itemID,
          practice: record.content,
          maturity: .pending,
          sourceRecordID: record.id,
          createdAt: record.createdAt,
          updatedAt: record.createdAt
        ))
    }
  }
}

private struct SidebarView: View {
  let items: [Item]
  let records: [ImprovementRecord]
  @Binding var selection: AppDestination?
  let onNewItem: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "leaf.fill").font(.title2).foregroundStyle(.mint)
        VStack(alignment: .leading, spacing: 2) {
          Text("日进").font(.title3.bold())
          Text("Daily Better").font(.caption).opacity(0.75)
        }
        Spacer(minLength: 4)
        Button("新增事项", systemImage: "plus", action: onNewItem)
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
          .font(.system(size: 16, weight: .medium))
          .accessibilityLabel("新增事项")
      }.padding(.horizontal, 14).padding(.top, 18)
      ScrollView {
        VStack(alignment: .leading, spacing: 5) {
          row("全部经验", symbol: "tablecells", destination: .allExperiences)
          row(
            "待整理", symbol: "tray", destination: .inbox,
            count: records.filter { $0.itemID == nil }.count)
          row("灵感扭蛋", symbol: "sparkles", destination: .inspiration)
          Divider().overlay(.white.opacity(0.2)).padding(.vertical, 12)
          ForEach(LifeArea.allCases) { area in
            Text(area.rawValue).font(.caption).foregroundStyle(.white.opacity(0.7))
              .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 4)
            ForEach(items.filter { $0.area == area }) { item in
              row(item.name, symbol: area.symbol, destination: .item(item.id))
            }
          }
        }
      }
      SettingsLink { Label("设置", systemImage: "gearshape") }
        .buttonStyle(.plain).padding(14)
    }
    .padding(.horizontal, 10)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.157, green: 0.345, blue: 0.322))
    .navigationTitle("日进")
  }

  private func row(_ title: String, symbol: String, destination: AppDestination, count: Int = 0)
    -> some View
  {
    Button {
      selection = destination
    } label: {
      HStack(spacing: 12) {
        Image(systemName: symbol).frame(width: 20)
        Text(title).lineLimit(1)
        Spacer(minLength: 0)
        if count > 0 {
          Text("\(count)").font(.caption)
            .padding(5).background(.white.opacity(0.15), in: .capsule)
        }
      }
      .padding(.horizontal, 12).frame(height: 38)
      .background(
        selection == destination ? Color.white.opacity(0.16) : .clear,
        in: .rect(cornerRadius: 7)
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selection == destination ? .isSelected : [])
  }
}
