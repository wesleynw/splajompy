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
//    textView.textColor = .label
    textView.isScrollEnabled = true
    textView.isEditable = true
    textView.isUserInteractionEnabled = true

    // Make sure initial text has proper font size and color
    let mutableText = NSMutableAttributedString(attributedString: text)
    if text.length > 0 {
      let fullRange = NSRange(location: 0, length: text.length)
      mutableText.addAttribute(
        .font,
        value: UIFont.preferredFont(forTextStyle: .body),
        range: fullRange
      )
//      mutableText.addAttribute(
//        .foregroundColor,
//        value: UIColor.label,
//        range: fullRange
//      )
      textView.attributedText = mutableText
    } else {
      textView.attributedText = text
    }

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !uiView.attributedText.isEqual(to: text) {
      let wasUpdatingFromViewModel = context.coordinator.isUpdatingFromViewModel
      context.coordinator.isUpdatingFromViewModel = true

      // Ensure text has proper font size and color
      let mutableText = NSMutableAttributedString(attributedString: text)
      if text.length > 0 {
        let fullRange = NSRange(location: 0, length: text.length)
        // Check if font attribute is already set to avoid unnecessary attribute changes
        if mutableText.attribute(.font, at: 0, effectiveRange: nil) == nil {
          mutableText.addAttribute(
            .font,
            value: UIFont.preferredFont(forTextStyle: .body),
            range: fullRange
          )
        }
        // Ensure regular text has default text color
        if mutableText.attribute(.foregroundColor, at: 0, effectiveRange: nil)
          == nil
        {
          mutableText.addAttribute(
            .foregroundColor,
            value: UIColor.label,
            range: fullRange
          )
        }
        uiView.attributedText = mutableText
      } else {
        uiView.attributedText = text
      }

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
