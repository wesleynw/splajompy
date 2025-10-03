import SwiftUI

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var cursorPosition: Int
  @Binding var cursorY: CGFloat
  var onTextChange: ((NSAttributedString) -> NSAttributedString)?

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
    textView.textContainer.lineBreakMode = .byWordWrapping
    textView.translatesAutoresizingMaskIntoConstraints = true
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)  // i don't think this is idiomatic, but it works for now

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if uiView.attributedText != text {
      let selection = uiView.selectedRange
      uiView.attributedText = text
      uiView.selectedRange = selection
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator($text, $cursorPosition, $cursorY, onTextChange: onTextChange)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<NSAttributedString>
    var cursorPosition: Binding<Int>
    var cursorY: Binding<CGFloat>
    var onTextChange: ((NSAttributedString) -> NSAttributedString)?

    init(
      _ text: Binding<NSAttributedString>, _ cursorPosition: Binding<Int>,
      _ cursorY: Binding<CGFloat>,
      onTextChange: ((NSAttributedString) -> NSAttributedString)?
    ) {
      self.text = text
      self.cursorPosition = cursorPosition
      self.cursorY = cursorY
      self.onTextChange = onTextChange
    }

    func textViewDidChange(_ textView: UITextView) {
      guard let attributedText = textView.attributedText else { return }
      let processedText = onTextChange?(attributedText) ?? attributedText
      self.text.wrappedValue = processedText
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
        }
      }
    }
  }
}
