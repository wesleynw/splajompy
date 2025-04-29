import SwiftUI

struct ContentTextView: View {
  let processedText: String

  init(text: String) {
    self.processedText = ContentTextView.processText(text)
  }

  var body: some View {
    Text(.init(processedText))
      .lineLimit(nil)
  }

  static func processText(_ input: String) -> String {
    let pattern = #"\{tag:(\d+):([^\}]+)\}"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(input.startIndex..., in: input)

    return regex.stringByReplacingMatches(
      in: input,
      range: range,
      withTemplate: "**[@$2](splajompy://user?id=$1&username=$2)**"
    )
  }
}
