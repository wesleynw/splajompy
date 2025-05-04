import SwiftUI

struct ContentTextView: View {
  let processedText: String

  init(text: String, facets: [Facet]) {
    self.processedText = ContentTextView.processText(text, facets: facets)
  }

  var body: some View {
    Text(.init(processedText))
      .lineLimit(nil)
  }

  static func processText(_ input: String, facets: [Facet]) -> String {
    var output = input

    for facet in facets.sorted() {
      let startIndex = input.index(input.startIndex, offsetBy: facet.indexStart)  // this is dumb
      let incrementedStartIndex = input.index(after: startIndex)
      let endIndex = input.index(input.startIndex, offsetBy: facet.indexEnd)
      let username = input[incrementedStartIndex..<endIndex]

      output.replaceSubrange(
        startIndex..<endIndex,
        with: "**[@\(username)](splajompy://user?id=\(facet.userId)&username=\(username))**")
    }

    let pattern = #"\{tag:(\d+):([^\}]+)\}"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(output.startIndex..., in: output)

    return regex.stringByReplacingMatches(
      in: output,
      range: range,
      withTemplate: "**[@$2](splajompy://user?id=$1&username=$2)**"
    )
  }
}
