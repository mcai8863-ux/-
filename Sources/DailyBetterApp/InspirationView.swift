import SwiftData
import SwiftUI

struct InspirationView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \InspirationDecision.decidedAt, order: .reverse) private var decisions:
    [InspirationDecision]
  @Query(sort: \InspirationExposure.seenAt, order: .reverse) private var exposures:
    [InspirationExposure]
  let items: [Item]

  @State private var turn = 0
  @State private var selectedArea: LifeArea?
  @State private var currentCard: InspirationCard?
  @State private var showingAdopt = false
  @State private var showingReject = false
  @State private var showingHistory = false
  private let cards = CardLibraryLoader.load()

  private var decidedIDs: Set<String> { Set(decisions.map(\.cardID)) }
  private var seenIDs: Set<String> { Set(exposures.map(\.cardID)) }
  private var candidates: [InspirationCard] {
    InspirationEngine.availableInRound(
      cards: cards, decidedIDs: decidedIDs, seenIDs: seenIDs, area: selectedArea)
  }
  private var undecidedInScope: [InspirationCard] {
    cards.filter {
      !decidedIDs.contains($0.id) && (selectedArea == nil || $0.category == selectedArea?.rawValue)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      if cards.isEmpty {
        ContentUnavailableView(
          "建议库载入失败", systemImage: "exclamationmark.triangle", description: Text("请检查内置内容文件。")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        singlePage
      }
    }
    .sheet(isPresented: $showingAdopt) {
      if let currentCard {
        AdoptInspirationView(card: currentCard, items: items) { completeCurrent() }
      }
    }
    .sheet(isPresented: $showingReject) {
      if let currentCard { RejectInspirationView(card: currentCard) { completeCurrent() } }
    }
    .sheet(isPresented: $showingHistory) {
      InspirationHistoryView(cards: cards, decisions: decisions)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("灵感扭蛋").font(.largeTitle.bold())
          Text("本轮剩余 \(candidates.count) 条 · 未决定 \(undecidedInScope.count) 条").foregroundStyle(
            .secondary)
        }
        Spacer()
        Button("处理记录", systemImage: "clock.arrow.circlepath") { showingHistory = true }
      }
      Picker("范围", selection: $selectedArea) {
        Text("全部").tag(nil as LifeArea?)
        ForEach(LifeArea.allCases) { area in Text(area.rawValue).tag(area as LifeArea?) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 420)
      .onChange(of: selectedArea) { currentCard = nil }
    }
    .padding(20)
  }

  private var singlePage: some View {
    HStack(alignment: .center, spacing: 24) {
      VStack(spacing: 18) {
        GashaponMachine(turn: turn)
        Button("扭一次", systemImage: "arrow.triangle.2.circlepath", action: draw)
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .keyboardShortcut(.return, modifiers: [])
          .disabled(candidates.isEmpty && currentCard == nil)
      }
      .frame(width: 190)

      Divider().frame(maxHeight: 360)

      VStack(alignment: .leading, spacing: 20) { suggestionArea }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .leading)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var suggestionArea: some View {
    if let currentCard {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Label(currentCard.category, systemImage: "circle.fill").foregroundStyle(.green)
          Text(currentCard.topic).foregroundStyle(.secondary)
        }
        Text(currentCard.action)
          .font(.system(.largeTitle, design: .rounded, weight: .semibold))
          .lineSpacing(8)
          .frame(maxWidth: 760, alignment: .leading)
        Text("可以采纳、不采纳，或者再想想，以后再次看到。")
          .foregroundStyle(.secondary)
        HStack(spacing: 12) {
          Button("采纳") { showingAdopt = true }
            .buttonStyle(.borderedProminent).controlSize(.large)
          Button("不采纳") { showingReject = true }
            .controlSize(.large)
          Button("再想想", action: draw)
            .controlSize(.large)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if candidates.isEmpty {
      if undecidedInScope.isEmpty {
        ContentUnavailableView(
          selectedArea == nil ? "所有建议都已决定" : "这个范围都已决定",
          systemImage: "checkmark.seal",
          description: Text("可以查看处理记录，或补充新的建议。")
        )
      } else {
        ContentUnavailableView(
          "本轮已播完",
          systemImage: "arrow.triangle.2.circlepath",
          description: Text("本轮只负责不重复地展示建议，不要求逐条做决定。")
        )
        Button("开始下一轮") { startNextRound() }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      }
    } else {
      ContentUnavailableView(
        "扭一个灵感",
        systemImage: "lightbulb",
        description: Text("点击左侧“扭一次”，建议会在这里直接刷新。")
      )
    }
  }

  private func draw() {
    turn += 1
    guard let card = candidates.randomElement() else {
      currentCard = nil
      return
    }
    modelContext.insert(InspirationExposure(cardID: card.id))
    try? modelContext.save()
    withAnimation(.easeInOut(duration: 0.18)) { currentCard = card }
  }
  private func completeCurrent() { currentCard = nil }

  private func startNextRound() {
    let scopeIDs = Set(undecidedInScope.map(\.id))
    exposures.filter { scopeIDs.contains($0.cardID) }.forEach(modelContext.delete)
    try? modelContext.save()
    currentCard = nil
  }
}

private struct AdoptInspirationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let card: InspirationCard
  let items: [Item]
  let onComplete: () -> Void
  @State private var content: String
  @State private var itemID: UUID?

  init(card: InspirationCard, items: [Item], onComplete: @escaping () -> Void) {
    self.card = card
    self.items = items
    self.onComplete = onComplete
    _content = State(initialValue: card.action)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("保存为想法").font(.title.bold())
      TextField("行动内容", text: $content, axis: .vertical).lineLimit(3...8)
      Picker("归入事项", selection: $itemID) {
        Text("暂不分类").tag(nil as UUID?)
        ForEach(items) { item in Text("\(item.area.rawValue) · \(item.name)").tag(item.id as UUID?)
        }
      }
      HStack {
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("保存想法") { save() }.buttonStyle(.borderedProminent).disabled(
          content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(24).frame(width: 520)
  }

  private func save() {
    let record = ImprovementRecord(
      itemID: itemID, content: content, kind: .idea, sourceCardID: card.id)
    modelContext.insert(record)
    if let itemID {
      modelContext.insert(
        Experience(itemID: itemID, practice: content, maturity: .pending, sourceRecordID: record.id)
      )
    }
    modelContext.insert(InspirationDecision(cardID: card.id, status: .adopted, recordID: record.id))
    try? modelContext.save()
    dismiss()
    onComplete()
  }
}

private struct RejectInspirationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  let card: InspirationCard
  let onComplete: () -> Void
  @State private var reason = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("不采纳这条建议？").font(.title2.bold())
      Text(card.action)
      TextField("原因（选填）", text: $reason, axis: .vertical).lineLimit(2...5)
      HStack {
        Spacer()
        Button("取消", role: .cancel) { dismiss() }
        Button("确认不采纳") { reject() }.buttonStyle(.borderedProminent)
      }
    }.padding(24).frame(width: 500)
  }

  private func reject() {
    modelContext.insert(InspirationDecision(cardID: card.id, status: .rejected, reason: reason))
    try? modelContext.save()
    dismiss()
    onComplete()
  }
}

private struct InspirationHistoryView: View {
  @Environment(\.dismiss) private var dismiss
  let cards: [InspirationCard]
  let decisions: [InspirationDecision]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("处理记录").font(.title.bold())
        Spacer()
        Button("完成") { dismiss() }
      }
      Table(decisions) {
        TableColumn("分类") { decision in Text(card(for: decision)?.category ?? "-") }.width(70)
        TableColumn("建议") { decision in
          Text(card(for: decision)?.action ?? decision.cardID).lineLimit(2)
        }.width(min: 300, ideal: 440)
        TableColumn("状态") { decision in Text(decision.statusRaw) }.width(80)
        TableColumn("处理日期") { decision in Text(decision.decidedAt, format: .dateTime.month().day())
        }.width(90)
      }.tableStyle(.bordered(alternatesRowBackgrounds: true))
    }.padding(20).frame(width: 760, height: 480)
  }

  private func card(for decision: InspirationDecision) -> InspirationCard? {
    cards.first { $0.id == decision.cardID }
  }
}
