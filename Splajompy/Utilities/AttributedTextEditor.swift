import SwiftUI
import UIKit

struct AttributedTextEditor: UIViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var height: CGFloat
  @Binding var cursorPosition: Int
  var onTextChange: ((NSAttributedString) -> Void)?
  var onCursorPositionChange: ((Int) -> Void)?

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.isEditable = true
    textView.isUserInteractionEnabled = true
    textView.autocorrectionType = .yes
    textView.backgroundColor = .clear
    textView.typingAttributes = [
      .font: UIFont.preferredFont(forTextStyle: .body),
      .foregroundColor: UIColor.label,
    ]
    textView.attributedText = text
    textView.isScrollEnabled = false
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textView.textContainer.lineFragmentPadding = 0

    // Calculate initial height
    DispatchQueue.main.async {
      let availableWidth = UIScreen.main.bounds.width - 32  // Accounting for horizontal padding
      let newSize = textView.sizeThatFits(
        CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
      height = newSize.height
    }

    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if !uiView.attributedText.isEqual(to: text) {
      context.coordinator.isUpdatingFromViewModel = true
      uiView.typingAttributes = [
        .font: UIFont.preferredFont(forTextStyle: .body),
        .foregroundColor: UIColor.label,
      ]
      uiView.attributedText = text
      if cursorPosition <= text.length {
        uiView.selectedRange = NSRange(location: cursorPosition, length: 0)
      }
      context.coordinator.isUpdatingFromViewModel = false
    }

    // Update height based on content
    DispatchQueue.main.async {
      let availableWidth =
        uiView.bounds.width > 0 ? uiView.bounds.width : UIScreen.main.bounds.width - 32
      let newSize = uiView.sizeThatFits(
        CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
      if height != newSize.height {
        height = newSize.height
      }
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
      if !isUpdatingFromViewModel {
        if let text = textView.text, !text.isEmpty {
          let lastChar = text[text.index(before: text.endIndex)]
          if lastChar == " " {
            textView.typingAttributes = [
              .font: UIFont.preferredFont(forTextStyle: .body),
              .foregroundColor: UIColor.label,
            ]
          }
        }

        if let attributedText = textView.attributedText {
          parent.text = attributedText
          parent.onTextChange?(attributedText)
        }

        if let position = textView.position(
          from: textView.beginningOfDocument,
          offset: textView.selectedRange.location
        ) {
          let cursorPosition = textView.offset(
            from: textView.beginningOfDocument,
            to: position
          )

          parent.cursorPosition = cursorPosition
          parent.onCursorPositionChange?(cursorPosition)
        }
      }

      // Update height after text changes
      DispatchQueue.main.async {
        let availableWidth =
          textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width - 32
        let newSize = textView.sizeThatFits(
          CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
        if self.parent.height != newSize.height {
          self.parent.height = newSize.height
        }
      }
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      if !isUpdatingFromViewModel {
        let cursorPosition = textView.selectedRange.location

        var isInMention = false
        if cursorPosition > 1 {
          let prevChar = textView.text[
            textView.text.index(textView.text.startIndex, offsetBy: cursorPosition - 2)]
          print("prev char: ", prevChar)
          if prevChar != " " {
            let attributes = textView.attributedText.attributes(
              at: cursorPosition - 1, effectiveRange: nil)
            if let foregroundColor = attributes[.foregroundColor] as? UIColor {
              isInMention = foregroundColor == UIColor.systemBlue
            }
          }
        }

        if !isInMention {
          textView.typingAttributes = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
          ]
        }

        parent.cursorPosition = cursorPosition
        parent.onCursorPositionChange?(cursorPosition)
      }
    }

    func textViewDidLayoutSubviews(_ textView: UITextView) {
      DispatchQueue.main.async {
        let availableWidth = textView.bounds.width
        let newSize = textView.sizeThatFits(
          CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
        if self.parent.height != newSize.height {
          self.parent.height = newSize.height
        }
      }
    }
  }
}
