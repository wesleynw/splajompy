import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var currentMention: String?
  @Binding var selectedRange: NSRange
  @Binding var cursorY: CGFloat

  var isScrollEnabled: Bool
  var trailingInset: CGFloat = 0
  var placeholder: String = ""

  private var centeredVerticalInset: CGFloat {
    let font = UIFont.preferredFont(forTextStyle: .body)
    let lineHeight = ceil(font.lineHeight)
    return max(5.0, (42.0 - lineHeight) / 2.0)
  }

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
    textView.textContainerInset = UIEdgeInsets(
      top: centeredVerticalInset,
      left: 10,
      bottom: centeredVerticalInset,
      right: 10 + trailingInset
    )
    textView.translatesAutoresizingMaskIntoConstraints = true
    textView.setContentCompressionResistancePriority(
      .defaultLow,
      for: .horizontal
    )
    textView.backgroundColor = .clear

    let label = UILabel()
    label.text = placeholder
    label.font = UIFont.preferredFont(forTextStyle: .body)
    label.textColor = .tertiaryLabel
    label.numberOfLines = 0
    label.isUserInteractionEnabled = false
    label.translatesAutoresizingMaskIntoConstraints = false
    textView.addSubview(label)
    let padding = textView.textContainer.lineFragmentPadding
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(
        equalTo: textView.topAnchor,
        constant: centeredVerticalInset
      ),
      label.leadingAnchor.constraint(
        equalTo: textView.leadingAnchor,
        constant: 10 + padding
      ),
      label.trailingAnchor.constraint(
        equalTo: textView.trailingAnchor,
        constant: -(10 + trailingInset + padding)
      ),
    ])
    context.coordinator.placeholderLabel = label

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    context.coordinator.isUpdating = true
    defer { context.coordinator.isUpdating = false }

    if uiView.attributedText != text {
      uiView.attributedText = text
    }

    if uiView.selectedRange != selectedRange {
      uiView.selectedRange = selectedRange
    }

    let expectedInset = UIEdgeInsets(
      top: centeredVerticalInset,
      left: 10,
      bottom: centeredVerticalInset,
      right: 10 + trailingInset
    )
    if uiView.textContainerInset != expectedInset {
      uiView.textContainerInset = expectedInset
    }

    context.coordinator.placeholderLabel?.isHidden = !text.string.isEmpty
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView: UITextView,
    context: Context
  ) -> CGSize? {
    let width = proposal.width ?? uiView.bounds.width
    let intrinsic = uiView.sizeThatFits(
      CGSize(width: width, height: .greatestFiniteMagnitude)
    )
    let lineHeight = ceil(UIFont.preferredFont(forTextStyle: .body).lineHeight)
    let minHeight = centeredVerticalInset * 2 + lineHeight
    let maxHeight = centeredVerticalInset * 2 + lineHeight * 8
    let height =
      isScrollEnabled
      ? min(max(intrinsic.height, minHeight), maxHeight)
      : max(intrinsic.height, minHeight)
    return CGSize(width: width, height: height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator($text, $currentMention, $selectedRange, $cursorY)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var isUpdating = false
    var text: Binding<NSAttributedString>
    var currentMention: Binding<String?>
    var selectedRange: Binding<NSRange>
    var cursorY: Binding<CGFloat>
    var placeholderLabel: UILabel?

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
      let styledText = MentionUtilities.applyMentionStyling(to: text)
      textView.attributedText = styledText
      textView.selectedRange = ranges

      self.selectedRange.wrappedValue = ranges
      self.text.wrappedValue = styledText
      checkForMention(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      guard !isUpdating else { return }
      let nsRange = textView.selectedRange

      if let selectedRange = textView.selectedTextRange {
        let position = textView.offset(
          from: textView.beginningOfDocument,
          to: selectedRange.start
        )

        let caretRect = textView.caretRect(for: selectedRange.start)
        self.selectedRange.wrappedValue = nsRange
        self.cursorY.wrappedValue = caretRect.maxY

        checkForMention(in: textView)

        let isInMention = MentionUtilities.isPositionInMention(
          in: textView.text,
          at: position
        )

        textView.typingAttributes = [
          .font: UIFont.preferredFont(forTextStyle: .body),
          .foregroundColor: isInMention ? UIColor.systemBlue : UIColor.label,
        ]
      }
    }

    private func checkForMention(in textView: UITextView) {
      guard !isUpdating else { return }
      guard let selectedRange = textView.selectedTextRange else {
        self.currentMention.wrappedValue = nil
        return
      }

      let cursorPosition = textView.offset(
        from: textView.beginningOfDocument,
        to: selectedRange.start
      )

      self.currentMention.wrappedValue = MentionUtilities.currentMention(
        in: textView.text ?? "",
        at: cursorPosition
      )
    }
  }
}
