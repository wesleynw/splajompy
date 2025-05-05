import SwiftUI

extension MentionTextEditor {
  @MainActor
  class MentionViewModel: ObservableObject {
    @Published var attributedText: NSAttributedString = NSAttributedString("")
    @Published var cursorPosition: Int = 0
    @Published var mentionSuggestions: [User] = []
    @Published var isShowingSuggestions = false

    private var service: ProfileServiceProtocol = ProfileService()
    private var mentionStartIndex: String.Index?
    private var mentionPrefix: String = ""
    private let mentionPattern = "@([a-zA-Z0-9_]+)"

    var plainText: String {
      attributedText.string
    }

    func updateAttributedText(_ text: NSAttributedString) {
      attributedText = text
      checkForMentionAtCursor()
    }

    func updateCursorPosition(_ position: Int) {
      cursorPosition = position
      checkForMentionAtCursor()
    }

    func processTextChange(_ newText: NSAttributedString) {
      let mutableText = NSMutableAttributedString(string: newText.string)
      let fullRange = NSRange(location: 0, length: newText.string.count)

      mutableText.addAttribute(
        .font,
        value: UIFont.preferredFont(forTextStyle: .body),
        range: fullRange
      )
      mutableText.addAttribute(
        .foregroundColor,
        value: UIColor.label,
        range: fullRange
      )

      let mentions = extractMentions(from: newText.string)
      for mention in mentions {
        let range = NSRange(
          location: mention.range.location,
          length: mention.range.length
        )
        mutableText.addAttribute(
          .foregroundColor,
          value: UIColor.systemBlue,
          range: range
        )
      }

      attributedText = mutableText
      checkForMentionAtCursor()
    }

    private struct Mention {
      let username: String
      let range: NSRange
    }

    private func extractMentions(from text: String) -> [Mention] {
      var mentions: [Mention] = []
      do {
        let regex = try NSRegularExpression(pattern: mentionPattern)
        let nsString = text as NSString
        let matches = regex.matches(
          in: text,
          range: NSRange(location: 0, length: nsString.length)
        )

        for match in matches {
          let range = match.range
          let username = nsString.substring(
            with: NSRange(
              location: range.location + 1,
              length: range.length - 1
            )
          )
          mentions.append(Mention(username: username, range: range))
        }
      } catch {
        print("Error creating regex: \(error)")
      }
      return mentions
    }

    private func checkForMentionAtCursor() {
      guard cursorPosition > 0, cursorPosition <= plainText.count else {
        clearMentionState()
        return
      }

      let textIndex = plainText.index(
        plainText.startIndex,
        offsetBy: cursorPosition - 1
      )

      // Check if we're immediately after a completed mention (space after @username)
      if plainText[textIndex] == " " {
        // Check if the character before the space is part of a mention
        let previousTextIndex = plainText.index(before: textIndex)
        if previousTextIndex >= plainText.startIndex {
          let possibleMentionRange = plainText[..<previousTextIndex]
          if let atSymbolIndex = possibleMentionRange.lastIndex(of: "@") {
            let mentionText = plainText[atSymbolIndex..<textIndex]
            // If this looks like a complete mention (@username), don't show suggestions
            if mentionText.count > 1 && !mentionText.contains(" ") {
              clearMentionState()
              return
            }
          }
        }
      }

      if let wordStart = plainText[..<textIndex].lastIndex(where: {
        $0 == "@" || $0 == " "
      }) {
        let potentialMentionStart =
          plainText[wordStart] == "@"
          ? wordStart : plainText.index(after: wordStart)

        if plainText[potentialMentionStart] == "@" {
          // Don't trigger for completed mentions with a space after them
          if plainText[textIndex] == " " && textIndex > potentialMentionStart {
            let mentionText = plainText[potentialMentionStart..<textIndex]
            if mentionText.count > 1 {
              clearMentionState()
              return
            }
          }

          let distanceFromMention =
            plainText.distance(from: potentialMentionStart, to: textIndex) + 1

          if distanceFromMention <= 20 {
            mentionStartIndex = potentialMentionStart
            let searchRange = plainText[
              potentialMentionStart..<plainText.index(
                plainText.startIndex,
                offsetBy: cursorPosition
              )
            ]
            mentionPrefix = String(searchRange.dropFirst())
            fetchSuggestions(prefix: mentionPrefix)
            return
          }
        }
      }

      clearMentionState()
    }

    private func clearMentionState() {
      mentionStartIndex = nil
      mentionPrefix = ""
      isShowingSuggestions = false
      mentionSuggestions = []
    }

    func fetchSuggestions(prefix: String) {
      // Always show suggestions when typing a mention, even if empty
      self.isShowingSuggestions = true

      Task {
        let response = await service.getUserFromUsernamePrefix(prefix: prefix)
        switch response {
        case .success(let users):
          await MainActor.run {
            self.mentionSuggestions = users
            // Keep showing suggestions even when the list is empty
            self.isShowingSuggestions = true
          }
        case .error:
          await MainActor.run {
            self.mentionSuggestions = []
            // Keep showing suggestions even on error
            self.isShowingSuggestions = true
          }
        }
      }
    }

    func insertMention(_ user: User) {
      guard let startIndex = mentionStartIndex else { return }

      var newText = plainText
      let currentIndex = newText.index(
        newText.startIndex,
        offsetBy: cursorPosition
      )
      let replaceRange = startIndex..<currentIndex
      let replacement = "@\(user.username) "
      newText.replaceSubrange(replaceRange, with: replacement)

      let mutableAttributedText = NSMutableAttributedString(string: newText)
      let fullRange = NSRange(location: 0, length: newText.count)
      mutableAttributedText.addAttribute(
        .font,
        value: UIFont.preferredFont(forTextStyle: .body),
        range: fullRange
      )
      mutableAttributedText.addAttribute(
        .foregroundColor,
        value: UIColor.label,
        range: fullRange
      )

      let mentions = extractMentions(from: newText)
      for mention in mentions {
        let range = NSRange(
          location: mention.range.location,
          length: mention.range.length
        )
        mutableAttributedText.addAttribute(
          .foregroundColor,
          value: UIColor.systemBlue,
          range: range
        )
      }

      attributedText = mutableAttributedText
      cursorPosition =
        newText.distance(from: newText.startIndex, to: startIndex)
        + replacement.count

      // Clear state before checkForMentionAtCursor to avoid showing suggestions after insertion
      clearMentionState()

      // Explicitly ensure UI updates by setting isShowingSuggestions to false again
      isShowingSuggestions = false
      mentionSuggestions = []
    }
  }
}
