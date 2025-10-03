import SwiftUI

extension MentionTextEditor {
  @MainActor
  class MentionViewModel: ObservableObject {
    @Published var mentionSuggestions: [User] = []
    @Published var isShowingSuggestions = false

    private var service: ProfileServiceProtocol = ProfileService()
    private var mentionStartIndex: String.Index?
    private var mentionPrefix: String = ""
    private let mentionPattern = "@([a-zA-Z0-9_.]+)"

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

    func checkForMention(in text: String, at cursorPosition: Int) {
      guard cursorPosition > 0, cursorPosition <= text.utf16.count else {
        clearMentionState()
        return
      }

      let cursorIndex =
        text.index(
          text.startIndex,
          offsetBy: cursorPosition,
          limitedBy: text.endIndex
        ) ?? text.endIndex

      if cursorPosition == 0
        || (cursorIndex < text.endIndex
          && (text[cursorIndex] == " " || text[cursorIndex] == "\n"))
      {
        clearMentionState()
        return
      }

      if let wordStart = text[..<cursorIndex].lastIndex(where: {
        $0 == "@" || $0 == " "
      }) {
        let potentialMentionStart =
          text[wordStart] == "@" ? wordStart : text.index(after: wordStart)

        if potentialMentionStart < text.endIndex
          && text[potentialMentionStart] == "@"
        {
          if cursorIndex < text.endIndex && text[cursorIndex] == " "
            && potentialMentionStart < cursorIndex
          {
            let mentionRange = potentialMentionStart..<cursorIndex
            let mentionText = text[mentionRange]
            if mentionText.count > 1 {
              return
            }
          }

          let distanceFromMention = text.distance(
            from: potentialMentionStart,
            to: cursorIndex
          )
          if distanceFromMention <= 20 {
            mentionStartIndex = potentialMentionStart
            let searchRange = text[potentialMentionStart..<cursorIndex]
            let newPrefix = String(searchRange.dropFirst())

            if newPrefix != mentionPrefix {
              mentionPrefix = newPrefix
              fetchSuggestions(prefix: mentionPrefix)
            }
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
      self.isShowingSuggestions = true

      Task {
        let response = await service.getUserFromUsernamePrefix(prefix: prefix)
        switch response {
        case .success(let users):
          await MainActor.run {
            self.mentionSuggestions = users
            if prefix.isEmpty {
              self.isShowingSuggestions = false
            }
          }
        case .error:
          await MainActor.run {
            self.mentionSuggestions = []
            if prefix.isEmpty {
              self.isShowingSuggestions = false
            }
          }
        }
      }
    }

    func insertMention(
      _ user: User, in attributedText: NSAttributedString, at cursorPosition: Int
    ) -> (text: NSAttributedString, newCursorPosition: Int) {
      guard let startIndex = mentionStartIndex else {
        return (attributedText, cursorPosition)
      }

      let text = attributedText.string

      let cursorIndex =
        text.index(
          text.startIndex,
          offsetBy: cursorPosition,
          limitedBy: text.endIndex
        ) ?? text.endIndex

      let replaceRange = startIndex..<cursorIndex
      let replacement = "@\(user.username) "

      var newText = text
      newText.replaceSubrange(replaceRange, with: replacement)

      let newAttributedText = applyMentionStyling(to: newText)

      let newCursorPosition =
        text.distance(from: text.startIndex, to: startIndex)
        + replacement.utf16.count

      clearMentionState()

      return (newAttributedText, newCursorPosition)
    }

    func isPositionInMention(in text: String, at position: Int) -> Bool {
      let mentions = extractMentions(from: text)
      return mentions.contains { mention in
        NSLocationInRange(position, mention.range)
      }
    }

    func applyMentionStyling(to text: String) -> NSAttributedString {
      let mutableAttributedText = NSMutableAttributedString(string: text)
      let fullRange = NSRange(location: 0, length: text.utf16.count)

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

      let mentions = extractMentions(from: text)
      for mention in mentions {
        mutableAttributedText.addAttribute(
          .foregroundColor,
          value: UIColor.systemBlue,
          range: mention.range
        )
      }

      return mutableAttributedText
    }
  }
}
