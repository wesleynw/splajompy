import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

extension MentionTextEditor {
  @MainActor @Observable
  class MentionViewModel {
    var mentionSuggestions: [PublicUser] = []
    var isShowingSuggestions = false
    var isLoading = false

    private var service: ProfileServiceProtocol = ProfileService()
    private var fetchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    func clearMentionState() {
      fetchTask?.cancel()
      debounceTask?.cancel()

      isShowingSuggestions = false
      isLoading = false
      mentionSuggestions = []
    }

    func fetchSuggestions(prefix: String) {
      debounceTask?.cancel()

      guard !prefix.isEmpty else {
        clearMentionState()
        return
      }

      self.isShowingSuggestions = true
      self.isLoading = true

      debounceTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms

        guard !Task.isCancelled else { return }

        await MainActor.run {
          self.fetchTask?.cancel()
        }

        let fetchTask = Task {
          let response = await service.getUserFromUsernamePrefix(prefix: prefix)

          guard !Task.isCancelled else { return }

          await MainActor.run {
            switch response {
            case .success(let users):
              self.mentionSuggestions = users
              self.isLoading = false
            case .error:
              self.mentionSuggestions = []
              self.isLoading = false
            }
          }
        }

        await MainActor.run {
          self.fetchTask = fetchTask
        }
      }
    }

    func insertMention(
      _ user: PublicUser,
      in attributedText: NSAttributedString,
      at selectedRange: NSRange
    ) -> (text: NSAttributedString, newSelectedRange: NSRange) {
      let text = attributedText.string

      let cursorPosition = selectedRange.location

      let cursorIndex =
        text.index(
          text.startIndex,
          offsetBy: cursorPosition,
          limitedBy: text.endIndex
        ) ?? text.endIndex

      let wordStartIndex =
        text[..<cursorIndex].lastIndex(where: { $0.isWhitespace })
        .map { text.index(after: $0) } ?? text.startIndex

      let wordEndIndex =
        text[cursorIndex...].firstIndex(where: { $0.isWhitespace })
        ?? text.endIndex

      let replaceRange = wordStartIndex..<wordEndIndex
      let replacement = "@\(user.username) "

      var newText = text
      newText.replaceSubrange(replaceRange, with: replacement)

      let mutableAttributedText = NSMutableAttributedString(string: newText)
      let fullRange = NSRange(location: 0, length: newText.utf16.count)

      #if os(iOS)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let labelColor = UIColor.label
        let mentionColor = UIColor.systemBlue
      #else
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let labelColor = NSColor.labelColor
        let mentionColor = NSColor.systemBlue
      #endif

      mutableAttributedText.addAttribute(
        .font,
        value: bodyFont,
        range: fullRange
      )
      mutableAttributedText.addAttribute(
        .foregroundColor,
        value: labelColor,
        range: fullRange
      )

      let mentions = MentionTextEditor.extractMentions(from: newText)
      for mention in mentions {
        mutableAttributedText.addAttribute(
          .foregroundColor,
          value: mentionColor,
          range: mention.range
        )
      }

      let newCursorPosition =
        text.distance(from: text.startIndex, to: wordStartIndex)
        + replacement.utf16.count

      let newSelectedRange = NSRange(location: newCursorPosition, length: 0)

      clearMentionState()

      return (mutableAttributedText, newSelectedRange)
    }
  }
}
