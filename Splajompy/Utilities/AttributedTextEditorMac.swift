import AppKit
import SwiftUI

struct AttributedTextEditor: NSViewRepresentable {
  @Binding var text: NSAttributedString
  @Binding var currentMention: String?
  @Binding var selectedRange: NSRange
  @Binding var cursorY: CGFloat
  @Binding var contentHeight: CGFloat

  var isScrollEnabled: Bool
  var trailingInset: CGFloat = 0

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView()
    textView.font = NSFont.preferredFont(forTextStyle: .body)
    textView.isEditable = true
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.isRichText = true
    textView.allowsUndo = true
    textView.textContainer?.lineFragmentPadding = 0
    if isScrollEnabled {
      textView.textContainerInset = NSSize(width: 8, height: 4)
    } else {
      textView.textContainerInset = .zero
    }
    textView.isAutomaticSpellingCorrectionEnabled = true
    textView.typingAttributes = [
      .font: NSFont.preferredFont(forTextStyle: .body),
      .foregroundColor: NSColor.labelColor,
    ]

    let storage = textView.textStorage!
    storage.setAttributedString(text)

    textView.delegate = context.coordinator

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = isScrollEnabled
    scrollView.drawsBackground = false
    scrollView.autohidesScrollers = true
    scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)

    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.widthTracksTextView = true

    context.coordinator.textView = textView

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

    nsView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: trailingInset)

    DispatchQueue.main.async {
      self.updateContentHeight(textView: textView)
    }
  }

  private func updateContentHeight(textView: NSTextView) {
    guard let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer
    else { return }
    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    let insetHeight =
      textView.textContainerInset.height * 2
    let newHeight = usedRect.height + insetHeight

    if abs(self.contentHeight - newHeight) > 1 {
      self.contentHeight = newHeight
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
      let styledText = applyMentionStyling(to: currentText)

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
          at: min(position, max(textView.string.utf16.count - 1, 0)))
        let glyphRange = NSRange(location: glyphIndex, length: 1)
        let boundingRect = layoutManager.boundingRect(
          forGlyphRange: glyphRange,
          in: textContainer
        )

        self.selectedRange.wrappedValue = nsRange
        self.cursorY.wrappedValue = boundingRect.origin.y
        self.checkForMention(in: textView)
      } else {
        self.selectedRange.wrappedValue = nsRange
        self.checkForMention(in: textView)
      }

      let isInMention = MentionTextEditor.isPositionInMention(
        in: textView.string,
        at: position
      )

      let typingColor: NSColor = isInMention ? .systemBlue : .labelColor
      textView.typingAttributes = [
        .font: NSFont.preferredFont(forTextStyle: .body),
        .foregroundColor: typingColor,
      ]
    }

    private func checkForMention(in textView: NSTextView) {
      let nsRange = textView.selectedRange()
      let cursorPosition = nsRange.location
      let text = textView.string

      guard cursorPosition > 0, cursorPosition <= text.count else {
        self.currentMention.wrappedValue = nil
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
          self.currentMention.wrappedValue = nil
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
        self.currentMention.wrappedValue = mentionPrefix
      } else {
        self.currentMention.wrappedValue = nil
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
        value: NSFont.preferredFont(forTextStyle: .body),
        range: fullRange
      )
      mutableAttributedText.addAttribute(
        .foregroundColor,
        value: NSColor.labelColor,
        range: fullRange
      )

      let mentions = MentionTextEditor.extractMentions(from: text.string)
      for mention in mentions {
        mutableAttributedText.addAttribute(
          .foregroundColor,
          value: NSColor.systemBlue,
          range: mention.range
        )
      }

      return mutableAttributedText
    }
  }
}
