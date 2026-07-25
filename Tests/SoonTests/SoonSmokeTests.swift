import SwiftTOMLEdit
import XCTest

@testable import Soon

final class SoonSmokeTests: XCTestCase {
  func testBuildInfoHasVersion() {
    XCTAssertFalse(BuildInfo.appVersion.isEmpty)
  }

  func testSwiftTOMLEditParseFailureAdapter() {
    let text = """
      [calendar]
      popup_mode =
      """
    let error = TOMLParseError(
      message: "expected value",
      start: 24,
      end: 24,
      line: 2,
      column: 14
    )

    let failure = makeSoonParseFailure(from: error, text: text)

    XCTAssertEqual(failure.configPath, "line 2, column 14")
    XCTAssertEqual(failure.problemItem, "[calendar].popup_mode")
    XCTAssertNil(failure.problemValue)
    XCTAssertEqual(
      failure.detail,
      "Could not parse TOML at line 2, column 14: expected value"
    )
  }
}
