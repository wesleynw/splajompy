import SwiftUI

struct MiniNotificationView: View {
  let text: String

  private var processedText: AttributedString {
    let markdown = generateAttributedStringUsingFacets(text, facets: [])
    return try! AttributedString(
      markdown: markdown,
      options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
      )
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(processedText)
        .font(.callout)
        .lineLimit(3)
        .foregroundColor(.secondary)
        .tint(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .frame(maxWidth: .infinity)
  }
}
