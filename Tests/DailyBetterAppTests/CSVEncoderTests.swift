import XCTest

@testable import DailyBetterApp

final class CSVEncoderTests: XCTestCase {
  func testEscapesCommaQuoteAndNewline() {
    XCTAssertEqual(CSVEncoder.escape("普通文字"), "普通文字")
    XCTAssertEqual(CSVEncoder.escape("有,逗号"), "\"有,逗号\"")
    XCTAssertEqual(CSVEncoder.escape("有\"引号"), "\"有\"\"引号\"")
    XCTAssertEqual(CSVEncoder.escape("两\n行"), "\"两\n行\"")
  }

  func testExportIncludesBOMHeaderAndCRLF() {
    let date = Date(timeIntervalSince1970: 0)
    let row = ExperienceExportRow(
      item: "写 PPT", group: "结构", practice: "先写结论", scenario: "汇报", effect: "更清楚", notes: "",
      status: "已沉淀", updatedAt: date)
    let csv = CSVEncoder.encode(rows: [row], calendar: Calendar(identifier: .gregorian))
    XCTAssertTrue(csv.hasPrefix("\u{FEFF}事项,分组,当前做法"))
    XCTAssertTrue(csv.contains("写 PPT,结构,先写结论,汇报,更清楚,,已沉淀"))
    XCTAssertTrue(csv.hasSuffix("\r\n"))
  }
}
