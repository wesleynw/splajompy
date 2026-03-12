import Testing

@testable import Splajompy

struct GreatestRemainderQuotaTests {

  @Test func testExactPercentages() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [25.0, 25.0, 25.0, 25.0])
    #expect(result == [25, 25, 25, 25])
  }

  @Test func testSimpleRounding() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [33.3, 33.3, 33.4])
    #expect(result == [33, 33, 34])
  }

  @Test func testClassicExample() {
    // Classic GRQ example: 41.667, 33.333, 25.0
    let result = calculateGreatestRemainderQuotaFromList(percentages: [41.667, 33.333, 25.0])
    #expect(result == [42, 33, 25])
  }

  @Test func testManySmallRemainders() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [
      16.6, 16.6, 16.6, 16.6, 16.6, 16.6,
    ])
    #expect(result == [17, 17, 17, 17, 16, 16])
  }

  @Test func testSingleOption() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [100.0])
    #expect(result == [100])
  }

  @Test func testZeroValues() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [100.0, 0.0, 0.0])
    #expect(result == [100, 0, 0])
  }

  @Test func testVerySmallValues() {
    let result = calculateGreatestRemainderQuotaFromList(percentages: [99.9, 0.05, 0.05])
    #expect(result == [100, 0, 0])
  }

  @Test func testFloatingPointPrecision() {
    // Test with floating point precision issues
    let result = calculateGreatestRemainderQuotaFromList(percentages: [
      33.333333, 33.333333, 33.333334,
    ])
    #expect(result == [33, 33, 34])
  }

  @Test func testInvalidSum() {
    // Should return nil when sum is not approximately 100
    let result = calculateGreatestRemainderQuotaFromList(percentages: [50.0, 25.0, 20.0])
    #expect(result == nil)
  }

  @Test func testResultSumsTo100() {
    // Property-based test: result should always sum to 100
    let inputs: [[Float]] = [
      [40.1, 30.2, 29.7],
      [10.1, 20.2, 30.3, 39.4],
      [5.5, 15.5, 25.5, 35.5, 18.0],
    ]

    for input in inputs {
      if let result = calculateGreatestRemainderQuotaFromList(percentages: input) {
        #expect(result.reduce(0, +) == 100)
      }
    }
  }
}
