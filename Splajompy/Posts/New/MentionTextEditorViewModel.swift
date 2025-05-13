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
      guard cursorPosition > 0, cursorPosition <= attributedText.string.count else {
        return
      }

      let textIndex = attributedText.string.index(
        attributedText.string.startIndex,
        offsetBy: cursorPosition - 1
      )

      if attributedText.string[textIndex] == " " || attributedText.string[textIndex] == "\n" {
        clearMentionState()
        return
      }

      if let wordStart = attributedText.string[..<textIndex].lastIndex(where: {
        $0 == "@" || $0 == " "
      }) {
        let potentialMentionStart =
          attributedText.string[wordStart] == "@"
          ? wordStart : attributedText.string.index(after: wordStart)

        if attributedText.string[potentialMentionStart] == "@" {
          if attributedText.string[textIndex] == " " && textIndex > potentialMentionStart {
            let mentionText = attributedText.string[potentialMentionStart..<textIndex]
            if mentionText.count > 1 {
              return
            }
          }

          let distanceFromMention =
            attributedText.string.utf8.distance(from: potentialMentionStart, to: textIndex) + 1

          if distanceFromMention <= 20 {
            mentionStartIndex = potentialMentionStart
            let searchRange = attributedText.string[
              potentialMentionStart..<attributedText.string.index(
                attributedText.string.startIndex,
                offsetBy: cursorPosition
              )
            ]
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

    func insertMention(_ user: User) {
      guard let startIndex = mentionStartIndex else { return }

      var newText = attributedText.string
      let currentIndex = newText.utf8.index(
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
        newText.distance(from: newText.utf8.startIndex, to: startIndex)
        + replacement.count

      clearMentionState()
    }
  }
}
