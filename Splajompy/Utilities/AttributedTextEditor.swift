import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var cursorPosition: Int
  @Binding var cursorY: CGFloat
  var viewModel: MentionTextEditor.MentionViewModel?

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
    textView.isScrollEnabled = false
    textView.translatesAutoresizingMaskIntoConstraints = true
    textView.setContentCompressionResistancePriority(
      .defaultLow,
      for: .horizontal
    )  // i don't think this is idiomatic, but it works for now

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !context.coordinator.isInternalUpdate && uiView.attributedText != text {
      uiView.attributedText = text
      uiView.selectedRange = NSRange(location: cursorPosition, length: 0)
    }
    context.coordinator.isInternalUpdate = false

    // Ensure text container width matches the view width for proper wrapping
    let size = uiView.bounds.size
    uiView.textContainer.size = CGSize(width: size.width, height: .greatestFiniteMagnitude)
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
