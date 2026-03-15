import AppKit
import SwiftUI

struct AttributedTextEditor: NSViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var currentMention: String?
  @Binding var selectedRange: NSRange
  @Binding var cursorY: CGFloat

  var isScrollEnabled: Bool
  var trailingInset: CGFloat = 0
  var placeholder: String = ""

  private var centeredVerticalInset: CGFloat {
    let font = NSFont.preferredFont(forTextStyle: .body)
    let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
    return (42.0 - lineHeight) / 2.0
  }

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView()
    textView.font = NSFont.preferredFont(forTextStyle: .body)
    textView.isEditable = true
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.isRichText = true
    textView.allowsUndo = true

    textView.isAutomaticSpellingCorrectionEnabled = true
    textView.typingAttributes = [
      .font: NSFont.preferredFont(forTextStyle: .body),
      .foregroundColor: NSColor.textColor,
    ]

    let storage = textView.textStorage!
    storage.setAttributedString(text)

    textView.delegate = context.coordinator

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = isScrollEnabled
    scrollView.drawsBackground = false
    scrollView.autohidesScrollers = true

    textView.textContainer?.widthTracksTextView = true
    textView.textContainerInset = NSSize(
      width: 0,
      height: centeredVerticalInset
    )

    context.coordinator.textView = textView

    let label = NSTextField(labelWithString: placeholder)
    label.font = NSFont.preferredFont(forTextStyle: .body)
    label.textColor = .tertiaryLabelColor
    label.translatesAutoresizingMaskIntoConstraints = false
    textView.addSubview(label)
    let padding = textView.textContainer?.lineFragmentPadding ?? 5
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
        lessThanOrEqualTo: textView.trailingAnchor,
        constant: -(10 + trailingInset + padding)
      ),
    ])
    context.coordinator.placeholderLabel = label

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    context.coordinator.isUpdating = true
    defer { context.coordinator.isUpdating = false }

    if textView.attributedString() != text {
      let selection = textView.selectedRange()
      textView.textStorage?.setAttributedString(text)
      textView.setSelectedRange(selection)
    }

    if textView.selectedRange() != selectedRange {
      textView.setSelectedRange(selectedRange)
    }

    textView.textContainerInset = NSSize(
      width: 10,
      height: centeredVerticalInset
    )

    context.coordinator.placeholderLabel?.isHidden = !text.string.isEmpty
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    nsView: NSScrollView,
    context: Context
  )
    -> CGSize?
  {
    let width = proposal.width ?? nsView.frame.width
    guard let textView = nsView.documentView as? NSTextView,
      let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer
    else { return nil }

    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)

    let font = NSFont.preferredFont(forTextStyle: .body)
    let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
    let minHeight = 42.0

    if isScrollEnabled {
      let maxHeight = (lineHeight * 10) + 30
      return CGSize(
        width: width,
        height: min(max(usedRect.height, minHeight), maxHeight)
      )
    } else {
      return CGSize(width: width, height: max(usedRect.height, minHeight))
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator($text, $currentMention, $selectedRange, $cursorY)
  }

  @MainActor class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<NSAttributedString>
    var currentMention: Binding<String?>
    var selectedRange: Binding<NSRange>
    var cursorY: Binding<CGFloat>
    var isUpdating = false
    weak var textView: NSTextView?
    var placeholderLabel: NSTextField?

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

    func textDidChange(_ notification: Foundation.Notification) {
      guard let textView = notification.object as? NSTextView,
        !isUpdating
      else { return }

      let currentText = textView.attributedString()
      let ranges = textView.selectedRange()
      let styledText = MentionUtilities.applyMentionStyling(to: currentText)

      isUpdating = true
      defer { isUpdating = false }

      textView.textStorage?.setAttributedString(styledText)
      textView.setSelectedRange(ranges)

      self.selectedRange.wrappedValue = ranges
      self.text.wrappedValue = styledText
      self.checkForMention(in: textView)
    }

    func textViewDidChangeSelection(_ notification: Foundation.Notification) {
      guard let textView = notification.object as? NSTextView,
        !isUpdating
      else { return }

      let nsRange = textView.selectedRange()
      let position = nsRange.location

      if let layoutManager = textView.layoutManager,
        let textContainer = textView.textContainer,
        position <= textView.string.utf16.count
      {
        let glyphIndex = layoutManager.glyphIndexForCharacter(
          at: min(position, max(textView.string.utf16.count - 1, 0))
        )
        let glyphRange = NSRange(location: glyphIndex, length: 1)
        let boundingRect = layoutManager.boundingRect(
          forGlyphRange: glyphRange,
          in: textContainer
        )

        self.selectedRange.wrappedValue = nsRange
        self.cursorY.wrappedValue =
          boundingRect.maxY + textView.textContainerInset.height
        self.checkForMention(in: textView)
      } else {
        self.selectedRange.wrappedValue = nsRange
        self.checkForMention(in: textView)
      }

      let isInMention = MentionUtilities.isPositionInMention(
        in: textView.string,
        at: position
      )

      print("is is mnention? ", isInMention)

      let typingColor: NSColor = isInMention ? .systemBlue : .labelColor
      textView.typingAttributes = [
        .font: NSFont.preferredFont(forTextStyle: .body),
        .foregroundColor: typingColor,
      ]
    }

    private func checkForMention(in textView: NSTextView) {
      self.currentMention.wrappedValue = MentionUtilities.currentMention(
        in: textView.string,
        at: textView.selectedRange().location
      )
    }
  }
}
