import SwiftUI

struct ContentTextView: View {
  let attributedText: AttributedString

  init(attributedText: AttributedString) {
    self.attributedText = attributedText
  }

  // Keep backward compatibility for other uses
  //  init(text: String, facets: [Facet]) {
  //    let processedText = generateAttributedStringUsingFacets(text, facets: facets)
  //    self.attributedText =
  //      (try? AttributedString(
  //        markdown: processedText,
  //        options: AttributedString.MarkdownParsingOptions(
  //          interpretedSyntax: .inlineOnlyPreservingWhitespace
  //        )
  //      )) ?? AttributedString(text)
  //  }

  var body: some View {
    Text(attributedText)
  }
}
