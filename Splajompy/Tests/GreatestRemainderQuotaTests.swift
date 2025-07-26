import XCTest

@testable import Splajompy

final class GreatestRemainderQuotaTests: XCTestCase {

  func testExactPercentages() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [25.0, 25.0, 25.0, 25.0])
    XCTAssertEqual(result, [25, 25, 25, 25])
  }

  func testSimpleRounding() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [33.3, 33.3, 33.4])
    XCTAssertEqual(result, [33, 33, 34])
  }

  func testClassicExample() {
    // Classic GRQ example: 41.667, 33.333, 25.0
    let result = calculateGreatestRemainderQuotaFromList(percentages: [41.667, 33.333, 25.0])
    XCTAssertEqual(result, [42, 33, 25])
  }

  func testManySmallRemainders() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [
      16.6, 16.6, 16.6, 16.6, 16.6, 16.6,
    ])
    XCTAssertEqual(result, [17, 17, 17, 17, 16, 16])
  }

  func testSingleOption() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [100.0])
    XCTAssertEqual(result, [100])
  }

  func testZeroValues() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [100.0, 0.0, 0.0])
    XCTAssertEqual(result, [100, 0, 0])
  }

  func testVerySmallValues() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [99.9, 0.05, 0.05])
    XCTAssertEqual(result, [100, 0, 0])
  }

  func testFloatingPointPrecision() {
    // Test with floating point precision issues
    let result = calculateGreatestRemainderQuotaFromList(percentages: [
      33.333333, 33.333333, 33.333334,
    ])
    XCTAssertEqual(result, [33, 33, 34])
  }

  func testInvalidSum() {
    // Should return nil when sum is not approximately 100
    let result = calculateGreatestRemainderQuotaFromList(percentages: [50.0, 25.0, 20.0])
    XCTAssertNil(result)
  }

  func testResultSumsTo100() {
    // Property-based test: result should always sum to 100
    let inputs: [[Float]] = [
      [40.1, 30.2, 29.7],
      [10.1, 20.2, 30.3, 39.4],
      [5.5, 15.5, 25.5, 35.5, 18.0],
    ]

    for input in inputs {
      if let result = calculateGreatestRemainderQuotaFromList(percentages: input) {
        XCTAssertEqual(result.reduce(0, +), 100, "Result should sum to 100 for input: \(input)")
      }
    }
  }
}
