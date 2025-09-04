import SwiftUI

struct GlitchText: View {
  let text: String
  let font: Font
  @State private var glitchOffset: CGFloat = 0
  @State private var timer: Timer?

  init(text: String, font: Font = .body) {
    self.text = text
    self.font = font
  }

  var body: some View {
    ZStack {
      Text(text)
        .font(font)
        .fontWeight(.bold)
        .foregroundColor(.red.opacity(0.6))
        .offset(x: -glitchOffset * 2, y: glitchOffset * 0.5)

      Text(text)
        .font(font)
        .fontWeight(.bold)
        .foregroundColor(.red)
        .offset(x: glitchOffset * 1.5, y: -glitchOffset * 0.3)
        .opacity(0.8)

      Text(text)
        .font(font)
        .fontWeight(.bold)
        .foregroundColor(.red)
        .offset(x: glitchOffset * 0.5, y: glitchOffset * 0.8)
    }
    .onAppear {
      startGlitching()
    }
    .onDisappear {
      timer?.invalidate()
    }
  }

  private func startGlitching() {
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      Task { @MainActor in
        withAnimation(.easeInOut(duration: 0.1)) {
          glitchOffset = CGFloat.random(in: -2...2)
        }
      }
    }
  }
}

struct MixedGlitchText: View {
  let text: String
  let triggerUsername: String
  let attributedText: AttributedString

  var body: some View {
    let glitchPattern = "@\(triggerUsername)"

    if let firstRange = text.range(of: glitchPattern) {
      let beforeGlitch = String(text[..<firstRange.lowerBound])
      let afterGlitchAttributed = getAttributedSubstring(
        from: attributedText, startingAt: beforeGlitch.count + glitchPattern.count)

      ViewThatFits(in: .horizontal) {
        flowingMixedLayout(
          beforeGlitch: beforeGlitch, afterGlitchAttributed: afterGlitchAttributed,
          glitchPattern: glitchPattern)
        wrappedMixedLayout(
          beforeGlitch: beforeGlitch, afterGlitchAttributed: afterGlitchAttributed,
          glitchPattern: glitchPattern)
      }
    } else {
      Text(attributedText)
    }
  }

  private func getAttributedSubstring(
    from attributedString: AttributedString, startingAt offset: Int
  ) -> AttributedString {
    let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: offset)
    if startIndex < attributedString.endIndex {
      return AttributedString(attributedString[startIndex...])
    } else {
      return AttributedString("")
    }
  }

  @ViewBuilder
  private func flowingMixedLayout(
    beforeGlitch: String, afterGlitchAttributed: AttributedString, glitchPattern: String
  ) -> some View {
    HStack(spacing: 0) {
      if !beforeGlitch.isEmpty {
        Text(beforeGlitch)
      }

      GlitchText(text: glitchPattern, font: .body)

      if !afterGlitchAttributed.characters.isEmpty {
        Text(afterGlitchAttributed)
      }
    }
  }

  @ViewBuilder
  private func wrappedMixedLayout(
    beforeGlitch: String, afterGlitchAttributed: AttributedString, glitchPattern: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 0) {
        if !beforeGlitch.isEmpty {
          Text(beforeGlitch)
        }

        GlitchText(text: glitchPattern, font: .body)

        if !afterGlitchAttributed.characters.isEmpty {
          Text(afterGlitchAttributed)
        }
      }
    }
  }

}

#Preview {
  VStack(spacing: 20) {
    GlitchText(text: "@giuseppe", font: .title2)
    GlitchText(text: "@giuseppe says hello", font: .body)
    GlitchText(text: "@giuseppe is here", font: .caption)
  }
  .padding()
}
