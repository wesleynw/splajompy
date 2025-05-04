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
    private let mentionPattern = "@([a-zA-Z0-9_]+)"
    private var recognizedUsernames: Set<String> = []

    func updateAttributedText(_ text: NSAttributedString) {
      attributedText = text
      plainText = text.string
    }

    func updateCursorPosition(_ position: Int) {
      cursorPosition = position
      checkForMentionAtCursor()
    }

    func processTextChange(_ newText: NSAttributedString) {
      // Create new attributed text with default styling
      let mutableText = NSMutableAttributedString(string: newText.string)
      let fullRange = NSRange(location: 0, length: newText.string.count)
      mutableText.addAttribute(
        .font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
      mutableText.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

      // Extract all mentions and update recognized usernames
      let mentions = extractMentions(from: newText.string)
      recognizedUsernames = Set(mentions.map { $0.username })

      // Highlight all mentions in the text
      for mention in mentions {
        let range = NSRange(location: mention.range.location, length: mention.range.length)
        mutableText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
      }

      attributedText = mutableText
      plainText = newText.string
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
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
          let range = match.range
          let username = nsString.substring(
            with: NSRange(location: range.location + 1, length: range.length - 1))
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

      let textIndex = plainText.index(plainText.startIndex, offsetBy: cursorPosition - 1)

      if let wordStart = plainText[..<textIndex].lastIndex(where: { $0 == "@" || $0 == " " }) {
        let potentialMentionStart =
          plainText[wordStart] == "@" ? wordStart : plainText.index(after: wordStart)

        if plainText[potentialMentionStart] == "@" {
          let distanceFromMention =
            plainText.distance(from: potentialMentionStart, to: textIndex) + 1

          if distanceFromMention <= 20 {
            mentionStartIndex = potentialMentionStart
            let searchRange = plainText[
              potentialMentionStart..<plainText.index(
                plainText.startIndex, offsetBy: cursorPosition)]
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
      let currentIndex = newText.index(newText.startIndex, offsetBy: cursorPosition)
      let replaceRange = startIndex..<currentIndex
      let replacement = "@\(user.username) "
      newText.replaceSubrange(replaceRange, with: replacement)

      // Add username to recognized set
      recognizedUsernames.insert(user.username)

      // Create new attributed text with default styling
      let mutableAttributedText = NSMutableAttributedString(string: newText)
      let fullRange = NSRange(location: 0, length: newText.count)
      mutableAttributedText.addAttribute(
        .font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
      mutableAttributedText.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

      // Apply mention styling to all mentions
      let mentions = extractMentions(from: newText)
      for mention in mentions {
        let range = NSRange(location: mention.range.location, length: mention.range.length)
        mutableAttributedText.addAttribute(
          .foregroundColor, value: UIColor.systemBlue, range: range)
      }

      attributedText = mutableAttributedText
      plainText = newText
      cursorPosition =
        newText.distance(from: newText.startIndex, to: startIndex) + replacement.count

      clearMentionState()
    }

    private func createBaseAttributedText(from text: String) -> NSMutableAttributedString {
      let mutableText = NSMutableAttributedString(string: text)
      let fullRange = NSRange(location: 0, length: text.count)
      mutableText.addAttribute(
        .font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
      mutableText.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
      return mutableText
    }

    private func applyMentionStyling(
      to attributedText: NSMutableAttributedString, start: Int, length: Int
    ) {
      let range = NSRange(location: start, length: length)
      attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
      attributedText.addAttribute(
        .font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
    }

    func applyMentionHighlighting() {
      let mutableAttributedText = createBaseAttributedText(from: plainText)

      do {
        let regex = try NSRegularExpression(pattern: mentionPattern)
        let nsString = plainText as NSString
        let matches = regex.matches(
          in: plainText, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
          applyMentionStyling(
            to: mutableAttributedText, start: match.range.location, length: match.range.length)
        }

        attributedText = mutableAttributedText
      } catch {
        print("Error creating regex: \(error)")
      }
    }
  }
}
