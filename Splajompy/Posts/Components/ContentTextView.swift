import PostHog
import SwiftUI

struct ContentTextView: View {
  private let attributedText: AttributedString
  private let shouldShowGlitch: Bool
  private let glitchData: (processedText: String, triggerUsername: String)?

  init(text: String, facets: [Facet]) {
    let isEasterEggEnabled = PostHogSDK.shared.isFeatureEnabled("beetlejuice-easter-egg")

    let result =
      isEasterEggEnabled
      ? EasterEggProcessor.processTripleUsernameEasterEgg(text, facets: facets) : nil

    let finalText = result?.shouldTrigger == true ? result!.processedText : text
    let finalFacets = result?.shouldTrigger == true ? result!.adjustedFacets : facets
    let markdown = generateAttributedStringUsingFacets(finalText, facets: finalFacets)

    self.attributedText =
      (try? AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )) ?? AttributedString(text)

    self.shouldShowGlitch = result?.shouldTrigger == true
    self.glitchData =
      result?.shouldTrigger == true ? (result!.processedText, result!.triggerUsername) : nil
  }
  init(attributedText: AttributedString) {
    self.attributedText = attributedText
    self.shouldShowGlitch = false
    self.glitchData = nil
  }

  var body: some View {
    if shouldShowGlitch, let glitchData = glitchData {
      MixedGlitchText(
        text: glitchData.processedText,
        triggerUsername: glitchData.triggerUsername,
        attributedText: attributedText
      )
    } else {
      Text(attributedText)
    }
  }
}
