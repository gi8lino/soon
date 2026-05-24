import XCTest

@testable import Soon

final class SoonSmokeTests: XCTestCase {
  func testBuildInfoHasVersion() {
    XCTAssertFalse(BuildInfo.appVersion.isEmpty)
  }
}
