import Foundation
import SwiftData

enum LifeArea: String, Codable, CaseIterable, Identifiable {
  case life = "生活"
  case work = "工作"
  case learning = "学习"

  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .life: "leaf"
    case .work: "briefcase"
    case .learning: "book"
    }
  }
}

enum ExperienceStatus: String, Codable, CaseIterable {
  case current = "当前有效"
  case review = "待复核"
  case notApplicable = "不再适用"
}

enum ExperienceMaturity: String, Codable, CaseIterable, Identifiable {
  case pending = "待验证"
  case testing = "验证中"
  case validated = "已沉淀"

  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .pending: "lightbulb"
    case .testing: "flask"
    case .validated: "checkmark.seal.fill"
    }
  }
}

@Model
final class Item {
  @Attribute(.unique) var id: UUID
  var areaRaw: String
  var name: String
  var goal: String
  var createdAt: Date

  init(id: UUID = UUID(), area: LifeArea, name: String, goal: String = "", createdAt: Date = .now) {
    self.id = id
    self.areaRaw = area.rawValue
    self.name = name
    self.goal = goal
    self.createdAt = createdAt
  }

  var area: LifeArea { LifeArea(rawValue: areaRaw) ?? .life }
}

@Model
final class ExperienceGroup {
  @Attribute(.unique) var id: UUID
  var itemID: UUID
  var name: String
  var sortOrder: Int

  init(id: UUID = UUID(), itemID: UUID, name: String, sortOrder: Int = 0) {
    self.id = id
    self.itemID = itemID
    self.name = name
    self.sortOrder = sortOrder
  }
}

@Model
final class Experience {
  @Attribute(.unique) var id: UUID
  var itemID: UUID
  var groupName: String
  var practice: String
  var scenario: String
  var effect: String
  var notes: String
  var statusRaw: String
  var maturityRaw: String = ExperienceMaturity.validated.rawValue
  var sourceRecordID: UUID?
  var createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(), itemID: UUID, groupName: String = "", practice: String,
    scenario: String = "", effect: String = "", notes: String = "",
    status: ExperienceStatus = .current, maturity: ExperienceMaturity = .validated,
    sourceRecordID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now
  ) {
    self.id = id
    self.itemID = itemID
    self.groupName = groupName
    self.practice = practice
    self.scenario = scenario
    self.effect = effect
    self.notes = notes
    self.statusRaw = status.rawValue
    self.maturityRaw = maturity.rawValue
    self.sourceRecordID = sourceRecordID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  var status: ExperienceStatus { ExperienceStatus(rawValue: statusRaw) ?? .current }
  var maturity: ExperienceMaturity {
    get { ExperienceMaturity(rawValue: maturityRaw) ?? .validated }
    set {
      maturityRaw = newValue.rawValue
      updatedAt = .now
    }
  }
}

enum RecordKind: String, Codable, CaseIterable {
  case unmarked = "未标注"
  case idea = "想法"
  case tried = "已尝试"
}

@Model
final class ImprovementRecord {
  @Attribute(.unique) var id: UUID
  var itemID: UUID?
  var content: String
  var kindRaw: String
  var createdAt: Date
  var sourceCardID: String?
  var judgmentRaw: String = "待观察"
  var preventAutomaticExperience: Bool = false
  var experienceID: UUID?

  init(
    id: UUID = UUID(), itemID: UUID? = nil, content: String, kind: RecordKind = .unmarked,
    createdAt: Date = .now, sourceCardID: String? = nil
  ) {
    self.id = id
    self.itemID = itemID
    self.content = content
    self.kindRaw = kind.rawValue
    self.createdAt = createdAt
    self.sourceCardID = sourceCardID
  }
}

extension ImprovementRecord {
  var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .unmarked }
}

enum InspirationDecisionStatus: String, Codable {
  case adopted = "已采纳"
  case rejected = "不采纳"
}

@Model
final class InspirationDecision {
  @Attribute(.unique) var cardID: String
  var statusRaw: String
  var decidedAt: Date
  var reason: String
  var recordID: UUID?

  init(
    cardID: String, status: InspirationDecisionStatus, reason: String = "", recordID: UUID? = nil,
    decidedAt: Date = .now
  ) {
    self.cardID = cardID
    self.statusRaw = status.rawValue
    self.decidedAt = decidedAt
    self.reason = reason
    self.recordID = recordID
  }
}

@Model
final class InspirationExposure {
  @Attribute(.unique) var cardID: String
  var seenAt: Date

  init(cardID: String, seenAt: Date = .now) {
    self.cardID = cardID
    self.seenAt = seenAt
  }
}

struct InspirationCard: Codable, Identifiable, Hashable {
  let id: String
  let category: String
  let topic: String
  let action: String
  let editorialStatus: String

  enum CodingKeys: String, CodingKey {
    case id, category, topic, action
    case editorialStatus = "editorial_status"
  }
}

private struct CardLibrary: Codable {
  let cards: [InspirationCard]
}

enum CardLibraryLoader {
  static func load(bundle: Bundle = .module) -> [InspirationCard] {
    let url =
      Bundle.main.url(forResource: "action-cards-600", withExtension: "json")
      ?? bundle.url(forResource: "action-cards-600", withExtension: "json")
    guard let url,
      let data = try? Data(contentsOf: url),
      let library = try? JSONDecoder().decode(CardLibrary.self, from: data)
    else { return [] }
    return library.cards
  }
}

enum InspirationEngine {
  static func availableInRound(
    cards: [InspirationCard], decidedIDs: Set<String>, seenIDs: Set<String>, area: LifeArea?
  ) -> [InspirationCard] {
    cards.filter { card in
      !decidedIDs.contains(card.id)
        && !seenIDs.contains(card.id)
        && (area == nil || card.category == area?.rawValue)
    }
  }
}
