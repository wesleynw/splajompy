import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var cursorPosition: Int
  @Binding var cursorY: CGFloat
  @Binding var contentHeight: CGFloat
  var viewModel: MentionTextEditor.MentionViewModel?
  var isScrollEnabled: Bool

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

    if isScrollEnabled {
      textView.textContainerInset = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
      textView.textContainer.lineFragmentPadding = 0
    }

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !context.coordinator.isInternalUpdate && uiView.attributedText != text {
      uiView.attributedText = text
      uiView.selectedRange = NSRange(location: cursorPosition, length: 0)
    }
    context.coordinator.isInternalUpdate = false

    let fixedWidth = uiView.bounds.width
    let size = uiView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))

    DispatchQueue.main.async {
      if abs(self.contentHeight - size.height) > 1 {
        self.contentHeight = size.height
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator($text, $cursorPosition, $cursorY, viewModel)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<NSAttributedString>
    var cursorPosition: Binding<Int>
    var cursorY: Binding<CGFloat>
    var viewModel: MentionTextEditor.MentionViewModel?
    var isInternalUpdate = false

    init(
      _ text: Binding<NSAttributedString>,
      _ cursorPosition: Binding<Int>,
      _ cursorY: Binding<CGFloat>,
      _ viewModel: MentionTextEditor.MentionViewModel?
    ) {
      self.text = text
      self.cursorPosition = cursorPosition
      self.cursorY = cursorY
      self.viewModel = viewModel
    }

    func textViewDidChange(_ textView: UITextView) {
      isInternalUpdate = true
      let currentText = textView.attributedText ?? NSAttributedString()
      self.text.wrappedValue = currentText
      //      textView.invalidateIntrinsicContentSize()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      if let selectedRange = textView.selectedTextRange {
        let position = textView.offset(
          from: textView.beginningOfDocument,
          to: selectedRange.start
        )
        let rect = textView.caretRect(for: selectedRange.start)

        DispatchQueue.main.async {
          self.cursorPosition.wrappedValue = position
          self.cursorY.wrappedValue = rect.maxY

          if let viewModel = self.viewModel {
            let text = textView.text ?? ""
            let isInMention = viewModel.isPositionInMention(
              in: text,
              at: position
            )

            if !isInMention {
              textView.typingAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
              ]
            }

            viewModel.checkForMention(in: text, at: position)
          }
        }
      }
    }
  }
}
