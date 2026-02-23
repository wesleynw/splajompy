import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var currentMention: String?
  @Binding var selectedRange: NSRange
  @Binding var cursorY: CGFloat
  @Binding var contentHeight: CGFloat

  var isScrollEnabled: Bool
  var trailingInset: CGFloat = 0

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.isEditable = true
    textView.isUserInteractionEnabled = true
    textView.autocorrectionType = .yes
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

    textView.backgroundColor = .clear

    textView.textContainer.lineFragmentPadding = 0
    if isScrollEnabled {
      textView.textContainerInset = UIEdgeInsets(
        top: 10,
        left: 10,
        bottom: 10,
        right: 10 + trailingInset
      )
    } else {
      textView.textContainerInset = .zero
    }

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if uiView.attributedText != text {
      uiView.attributedText = text
    }

    if uiView.selectedRange != selectedRange {
      uiView.selectedRange = selectedRange
    }

    if isScrollEnabled {
      let expectedInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10 + trailingInset)
      if uiView.textContainerInset != expectedInset {
        uiView.textContainerInset = expectedInset
      }
    }

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
    Coordinator($text, $currentMention, $selectedRange, $cursorY)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<NSAttributedString>
    var currentMention: Binding<String?>
    var selectedRange: Binding<NSRange>
    var cursorY: Binding<CGFloat>

    init(
      _ text: Binding<NSAttributedString>,
      _ currentMention: Binding<String?>,
      _ selectedRange: Binding<NSRange>,
      _ cursorY: Binding<CGFloat>
    ) {
      self.text = text
      self.currentMention = currentMention
      self.selectedRange = selectedRange
      self.cursorY = cursorY
    }

    func textViewDidChange(_ textView: UITextView) {
      let text =
        textView.attributedText ?? NSAttributedString(string: "")

      let ranges = textView.selectedRange
      let styledText = applyMentionStyling(to: text)
      textView.attributedText = styledText
      textView.selectedRange = ranges

      self.selectedRange.wrappedValue = ranges
      self.text.wrappedValue = styledText
      checkForMention(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      let nsRange = textView.selectedRange

      if let selectedRange = textView.selectedTextRange {
        let position = textView.offset(
          from: textView.beginningOfDocument,
          to: selectedRange.start
        )

        let caretRect = textView.caretRect(for: selectedRange.start)
        DispatchQueue.main.async {
          self.selectedRange.wrappedValue = nsRange
          self.cursorY.wrappedValue = caretRect.origin.y
        }

        checkForMention(in: textView)

        let isInMention = MentionTextEditor.isPositionInMention(
          in: textView.text,
          at: position
        )

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

      let wordEndIndex =
        text[cursorIndex...].firstIndex(where: { $0.isWhitespace })
        ?? text.endIndex

      let currentWord = String(text[wordStartIndex..<wordEndIndex])

      if currentWord.hasPrefix("@"), currentWord.count <= 25 {
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

    private func applyMentionStyling(to text: NSAttributedString)
      -> NSAttributedString
    {
      let mutableAttributedText = NSMutableAttributedString(
        attributedString: text
      )
      let fullRange = NSRange(location: 0, length: text.length)

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

      let mentions = MentionTextEditor.extractMentions(from: text.string)
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
