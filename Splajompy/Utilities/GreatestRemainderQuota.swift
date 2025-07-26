/// Given a list of floating-point numbers that add to 100, uses the greatest remainder quota
/// algorithm to return a fair list of those floats as integers.
///
/// - Parameter percentages: A list of floating point numbers.
/// - Returns: A new list of integers, or `nil` if input doesn't sum to approximately 100.
func calculateGreatestRemainderQuotaFromList(percentages: [Float]) -> [Int]? {
  // allow a little leeway for FP precision
  guard abs(percentages.reduce(0, +) - 100) <= 1 else { return nil }

  var trucatedPercentages = percentages.map { Int($0) }

  let indexRemainderArray = percentages.enumerated().map {
    (index, percentage) in
    (index: index, remainder: percentage.truncatingRemainder(dividingBy: 1))
  }.sorted { a, b in
    a.remainder > b.remainder
  }

  let remainingPoints = 100 - trucatedPercentages.reduce(0, +)

  for i in 0..<min(remainingPoints, indexRemainderArray.count) {
    let indexToIncrement = indexRemainderArray[i].index
    trucatedPercentages[indexToIncrement] += 1
  }

  return trucatedPercentages
}
