import SwiftUI

extension MentionTextEditor {
  @MainActor
  class MentionViewModel: ObservableObject {
    @Published var plainText: String = ""
    @Published var attributedText: NSAttributedString = NSAttributedString("")
    @Published var cursorPosition: Int = 0

    @Published var mentionSuggestions: [User] = []
    @Published var isShowingSuggestions = false

    private var service: ProfileServiceProtocol = ProfileService()
    private var mentionStartIndex: String.Index?
    private var mentionPrefix: String = ""

    func updateAttributedText(_ text: NSAttributedString) {
      attributedText = text
      plainText = text.string
    }

    func updateCursorPosition(_ position: Int) {
      cursorPosition = position
      checkForMentionAtCursor()
    }

    func processTextChange(_ newText: NSAttributedString) {
      plainText = newText.string
      attributedText = newText
      checkForMentionAtCursor()
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

      if let wordStart = plainText[..<textIndex].lastIndex(where: {
        $0 == "@" || $0 == " "
      }) {
        let potentialMentionStart =
          plainText[wordStart] == "@"
          ? wordStart : plainText.index(after: wordStart)

        if plainText[potentialMentionStart] == "@" {
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
            let mentionText = String(searchRange.dropFirst())

            mentionPrefix = mentionText
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
    }

    func fetchSuggestions(prefix: String) {
      Task {
        let response = await service.getUserFromUsernamePrefix(prefix: prefix)
        switch response {
        case .success(let users):
          self.mentionSuggestions = users
          self.isShowingSuggestions = !users.isEmpty
        case .error:
          self.mentionSuggestions = []
          self.isShowingSuggestions = false
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

      // Apply base styling to entire text first
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

      let mentionStart = newText.distance(
        from: newText.startIndex,
        to: startIndex
      )
      let mentionLength = replacement.count

      applyMentionStyling(
        to: mutableAttributedText,
        start: mentionStart,
        length: mentionLength
      )

      attributedText = mutableAttributedText
      plainText = newText

      // Set cursor position to end of mention + space
      cursorPosition = mentionStart + replacement.count

      clearMentionState()
      applyMentionHighlighting()
    }

    private func applyMentionStyling(
      to attributedText: NSMutableAttributedString,
      start: Int,
      length: Int
    ) {
      let range = NSRange(location: start, length: length)

      attributedText.addAttribute(
        .foregroundColor,
        value: UIColor.blue,
        range: range
      )
      attributedText.addAttribute(
        .backgroundColor,
        value: UIColor.blue.withAlphaComponent(0.1),
        range: range
      )
      attributedText.addAttribute(
        .font,
        value: UIFont.preferredFont(forTextStyle: .body),
        range: range
      )
    }

    func applyMentionHighlighting() {
      let mutableAttributedText = NSMutableAttributedString(string: plainText)

      // Apply base styling to entire text first
      let fullRange = NSRange(location: 0, length: plainText.count)
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

      let pattern = "@([a-zA-Z0-9_]+)"

      do {
        let regex = try NSRegularExpression(pattern: pattern)
        let nsString = plainText as NSString
        let matches = regex.matches(
          in: plainText,
          range: NSRange(location: 0, length: nsString.length)
        )

        for match in matches {
          applyMentionStyling(
            to: mutableAttributedText,
            start: match.range.location,
            length: match.range.length
          )
        }

        attributedText = mutableAttributedText
      } catch {
        print("Error creating regex: \(error)")
      }
    }

    private func attributedString(from text: String) -> NSAttributedString {
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.preferredFont(forTextStyle: .body)
      ]
      return NSAttributedString(string: text, attributes: attributes)
    }
  }
}
