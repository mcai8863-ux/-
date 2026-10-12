import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ExperienceExportRow: Equatable {
  let item: String
  let group: String
  let practice: String
  let scenario: String
  let effect: String
  let notes: String
  let status: String
  let updatedAt: Date
}

enum CSVEncoder {
  static let header = ["事项", "分组", "当前做法", "适用场景", "观察效果", "注意事项", "成熟度", "最近调整"]

  static func encode(rows: [ExperienceExportRow], calendar: Calendar = .current) -> String {
    var lines = [header.map(escape).joined(separator: ",")]
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    lines += rows.map { row in
      [
        row.item, row.group, row.practice, row.scenario, row.effect, row.notes, row.status,
        formatter.string(from: row.updatedAt),
      ]
      .map(escape)
      .joined(separator: ",")
    }
    return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
  }

  static func escape(_ value: String) -> String {
    guard
      value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
    else { return value }
    return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
}

struct CSVDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.commaSeparatedText] }
  let content: String

  init(content: String) { self.content = content }
  init(configuration: ReadConfiguration) throws {
    content = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(content.utf8))
  }
}
