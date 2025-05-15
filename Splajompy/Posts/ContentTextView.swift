import SwiftUI

struct ContentTextView: View {
  let processedText: String

  init(text: String, facets: [Facet]) {
    self.processedText = ContentTextView.processText(text, facets: facets)
  }

  var body: some View {
    Text(try! AttributedString(markdown: processedText))
      .lineLimit(nil)
  }

  static func processText(_ input: String, facets: [Facet]) -> String {
    var output = input

    for facet in facets.sorted(by: { $0.indexStart > $1.indexStart }) {
      guard facet.indexStart < input.utf8.count,
        facet.indexEnd <= input.utf8.count,
        facet.indexStart < facet.indexEnd
      else { continue }

      let utf8Start = input.utf8.index(input.utf8.startIndex, offsetBy: facet.indexStart)
      let utf8End = input.utf8.index(input.utf8.startIndex, offsetBy: facet.indexEnd)

      guard let startIndex = utf8Start.samePosition(in: input),
        let endIndex = utf8End.samePosition(in: input)
      else { continue }

      let incrementedStartIndex = input.index(after: startIndex)
      let username = String(input[incrementedStartIndex..<endIndex])

      output.replaceSubrange(
        startIndex..<endIndex,
        with: " **[@\(username)](splajompy://user?id=\(facet.userId)&username=\(username))**"
      )
    }

    let pattern = #"\{tag:(\d+):([^\}]+)\}"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(output.startIndex..., in: output)

    return regex.stringByReplacingMatches(
      in: output,
      range: range,
      withTemplate: "[\\@$2](splajompy://user?id=$1&username=$2)"
    )
  }
}
