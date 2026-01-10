import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var currentMention: String?
  @Binding var cursorPosition: Int
  @Binding var cursorY: CGFloat
  @Binding var contentHeight: CGFloat

  var isScrollEnabled: Bool

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.isEditable = true
    textView.isUserInteractionEnabled = true
    textView.autocorrectionType = .yes
    textView.spellCheckingType = .no
    textView.typingAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    textView.attributedText = text
    textView.isScrollEnabled = isScrollEnabled
    textView.translatesAutoresizingMaskIntoConstraints = true
    textView.setContentCompressionResistancePriority(
      .defaultLow,
      for: .horizontal
    )

    if isScrollEnabled {
      textView.textContainerInset = UIEdgeInsets(
        top: 4,
        left: 8,
        bottom: 4,
        right: 8
      )
      textView.textContainer.lineFragmentPadding = 0
    }

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !context.coordinator.isInternalUpdate && uiView.attributedText != text {
      uiView.attributedText = text

    }
    context.coordinator.isInternalUpdate = false

    let fixedWidth = uiView.bounds.width
    let size = uiView.sizeThatFits(
      CGSize(width: fixedWidth, height: .greatestFiniteMagnitude)
    )

    DispatchQueue.main.async {
      if abs(self.contentHeight - size.height) > 1 {
        self.contentHeight = size.height
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator($text, $currentMention, $cursorPosition, $cursorY)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<NSAttributedString>
    var currentMention: Binding<String?>
    var cursorPosition: Binding<Int>
    var cursorY: Binding<CGFloat>
    var isInternalUpdate = false

    init(
      _ text: Binding<NSAttributedString>,
      _ currentMention: Binding<String?>,
      _ cursorPosition: Binding<Int>,
      _ cursorY: Binding<CGFloat>
    ) {
      self.text = text
      self.currentMention = currentMention
      self.cursorPosition = cursorPosition
      self.cursorY = cursorY
    }

    func textViewDidChange(_ textView: UITextView) {
      isInternalUpdate = true

      let plainText = textView.text ?? ""

      let styledText = applyMentionStyling(to: plainText)

      let selectedRange = textView.selectedRange

      textView.attributedText = styledText
      textView.selectedRange = selectedRange

      self.text.wrappedValue = styledText

      checkForMention(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      if let selectedRange = textView.selectedTextRange {
        let position = textView.offset(
          from: textView.beginningOfDocument,
          to: selectedRange.start
        )

        let caretRect = textView.caretRect(for: selectedRange.start)
        DispatchQueue.main.async {
          self.cursorPosition.wrappedValue = position
          self.cursorY.wrappedValue = caretRect.origin.y
        }

        checkForMention(in: textView)

        let isInMention = MentionTextEditor.isPositionInMention(in: textView.text, at: position)

        DispatchQueue.main.async {
          textView.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: isInMention ? UIColor.systemBlue : UIColor.label,
          ]
        }
      }
    }

    private func checkForMention(in textView: UITextView) {
      guard let selectedRange = textView.selectedTextRange else {
        DispatchQueue.main.async {
          self.currentMention.wrappedValue = nil
        }
        return
      }

      let cursorPosition = textView.offset(
        from: textView.beginningOfDocument,
        to: selectedRange.start
      )

      let text = textView.text ?? ""

      guard cursorPosition > 0, cursorPosition <= text.count else {
        DispatchQueue.main.async {
          self.currentMention.wrappedValue = nil
        }
        return
      }

      let cursorIndex =
        text.index(
          text.startIndex,
          offsetBy: cursorPosition,
          limitedBy: text.endIndex
        ) ?? text.endIndex

      if cursorIndex > text.startIndex {
        let beforeCursor = text.index(before: cursorIndex)
        if text[beforeCursor] == " " || text[beforeCursor] == "\n" {
          DispatchQueue.main.async {
            self.currentMention.wrappedValue = nil
          }
          return
        }
      }

      let wordStartIndex =
        text[..<cursorIndex].lastIndex(where: { $0.isWhitespace })
        .map { text.index(after: $0) } ?? text.startIndex

      let currentWord = String(text[wordStartIndex..<cursorIndex])

      if currentWord.hasPrefix("@"), currentWord.count <= 21 {
        let mentionPrefix = String(currentWord.dropFirst())
        DispatchQueue.main.async {
          self.currentMention.wrappedValue = mentionPrefix
        }
      } else {
        DispatchQueue.main.async {
          self.currentMention.wrappedValue = nil
        }
      }
    }

    private func applyMentionStyling(to text: String) -> NSAttributedString {
      let mutableAttributedText = NSMutableAttributedString(string: text)
      let fullRange = NSRange(location: 0, length: text.utf16.count)

      mutableAttributedText.addAttribute(
        .font,
        value: UIFont.preferredFont(forTextStyle: .body),
        range: fullRange
      )
      mutableAttributedText.addAttribute(
        .foregroundColor,
        value: UIColor.label,
        range: fullRange
      )

      let mentions = MentionTextEditor.extractMentions(from: text)
      for mention in mentions {
        mutableAttributedText.addAttribute(
          .foregroundColor,
          value: UIColor.systemBlue,
          range: mention.range
        )
      }

      return mutableAttributedText
    }
  }
}
