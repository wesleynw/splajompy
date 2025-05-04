import SwiftUI
import UIKit

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var cursorPosition: Int
  var onTextChange: ((NSAttributedString) -> Void)?
  var onCursorPositionChange: ((Int) -> Void)?

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.isScrollEnabled = true
    textView.isEditable = true
    textView.isUserInteractionEnabled = true
    textView.autocorrectionType = .no
    textView.typingAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    textView.attributedText = text
    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !uiView.attributedText.isEqual(to: text) {
      let wasUpdatingFromViewModel = context.coordinator.isUpdatingFromViewModel
      context.coordinator.isUpdatingFromViewModel = true

      // Ensure typing attributes are set to default
      uiView.typingAttributes = [
        .font: UIFont.preferredFont(forTextStyle: .body),
        .foregroundColor: UIColor.label,
      ]

      uiView.attributedText = text

      if wasUpdatingFromViewModel && cursorPosition <= text.length {
        uiView.selectedRange = NSRange(location: cursorPosition, length: 0)
      }

      context.coordinator.isUpdatingFromViewModel = false
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var parent: AttributedTextEditor
    var isUpdatingFromViewModel = false

    init(_ parent: AttributedTextEditor) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      if let attributedText = textView.attributedText {
        // Check if the last character is a space
        if let lastChar = textView.text.last, lastChar == " " {
          // Reset typing attributes to default
          textView.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
          ]
        }

        parent.text = attributedText
        parent.onTextChange?(attributedText)
      }

      let cursorPosition = textView.selectedRange.location
      parent.cursorPosition = cursorPosition
      parent.onCursorPositionChange?(cursorPosition)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      if !isUpdatingFromViewModel {
        let cursorPosition = textView.selectedRange.location
        parent.cursorPosition = cursorPosition
        parent.onCursorPositionChange?(cursorPosition)
      }
    }
  }
}
