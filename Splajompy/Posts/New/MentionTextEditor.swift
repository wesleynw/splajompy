import SwiftUI

@MainActor
class MentionViewModel: ObservableObject {
  @Published var text: String = ""
  @Published var attributedText = NSAttributedString()
  @Published var mentionSuggestions: [User] = []
  @Published var isShowingSuggestions = false

  private var service: ProfileServiceProtocol = ProfileService()

  private var mentionStartIndex: String.Index?
  private var mentionPrefix: String = ""
  private var lastFetchTask: DispatchWorkItem?

  // Process text to detect mention patterns
  func processTextChange() {
    // Cancel any pending fetch to avoid excessive API calls
    lastFetchTask?.cancel()

    // Look for the most recent @ that's not part of a completed mention
    if let (startIndex, prefix) = findCurrentMentionPrefix(in: text) {
      self.mentionStartIndex = startIndex
      self.mentionPrefix = prefix

      // Create a new task for fetching with delay
      let task = DispatchWorkItem { [weak self] in
        self?.fetchSuggestions(prefix: prefix)
      }

      // Store the task and execute after a short delay
      lastFetchTask = task
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    } else {
      // No active mention being typed
      isShowingSuggestions = false
      mentionStartIndex = nil
      mentionPrefix = ""
    }

    // Apply highlighting to any completed mentions
    applyMentionHighlighting()
  }

  // Find the @ symbol and extract the prefix being typed
  private func findCurrentMentionPrefix(in text: String) -> (
    startIndex: String.Index, prefix: String
  )? {
    // Look for the pattern: space or start of text, followed by @, followed by word characters
    let mentionPattern = "(?<=^|\\s)@([\\w]*)"

    guard let regex = try? NSRegularExpression(pattern: mentionPattern) else {
      return nil
    }

    let nsString = text as NSString
    let range = NSRange(location: 0, length: nsString.length)

    // Find all matches, then get the last one (most recent mention)
    let matches = regex.matches(in: text, range: range)
    guard let lastMatch = matches.last else {
      return nil
    }

    // Extract the position and prefix
    let matchStartIndex = text.index(
      text.startIndex,
      offsetBy: lastMatch.range.location
    )
    let atSignIndex = matchStartIndex

    // Extract the prefix (characters after the @)
    var prefix = ""
    if lastMatch.numberOfRanges > 1 {
      let prefixRange = lastMatch.range(at: 1)
      prefix = nsString.substring(with: prefixRange)
    }

    return (atSignIndex, prefix)
  }

  func fetchSuggestions(prefix: String) {
    Task {
      let response = await service.getUserFromUsernamePrefix(prefix: prefix)
      switch response {
      case .success(let users):
        self.mentionSuggestions = users
        self.isShowingSuggestions = !users.isEmpty
      case .error:
        print("error")
      }
    }
  }

  // Apply the selection of a user from the suggestions
  func selectUser(_ user: User) {
    guard let mentionStartIndex = mentionStartIndex else { return }

    // Calculate the range to replace
    let mentionPrefixEndIndex = text.index(
      mentionStartIndex,
      offsetBy: mentionPrefix.count + 1
    )  // +1 for @ symbol
    let replaceRange = mentionStartIndex..<mentionPrefixEndIndex

    // Replace the @prefix with the full username
    text = text.replacingCharacters(in: replaceRange, with: "@\(user.username)")

    // Hide suggestions
    isShowingSuggestions = false

    // Apply highlighting to the new mention
    applyMentionHighlighting()
  }

  // Apply highlighting to all completed mentions
  private func applyMentionHighlighting() {
    let attributedString = NSMutableAttributedString(string: text)

    // Find all completed mentions
    let pattern = "@([a-zA-Z0-9_]+)\\b"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

    let nsString = text as NSString
    let matches = regex.matches(
      in: text,
      range: NSRange(location: 0, length: nsString.length)
    )

    for match in matches {
      attributedString.addAttribute(
        .foregroundColor,
        value: UIColor.systemBlue,
        range: match.range
      )
      attributedString.addAttribute(
        .font,
        value: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize),
        range: match.range
      )
    }

    self.attributedText = attributedString
  }
}

struct MentionTextEditor: View {
  @Binding var text: String
  var onTextChange: ((String) -> Void)?

  @StateObject private var internalViewModel = MentionViewModel()

  var body: some View {
    VStack {
      ZStack(alignment: .topLeading) {
        TextEditor(text: $internalViewModel.text)
          .padding(4)
          .onChange(of: internalViewModel.text) { oldValue, newValue in
            internalViewModel.processTextChange()
            applyAttributedText()
            text = newValue
            onTextChange?(newValue)
          }
          .onAppear {
            internalViewModel.text = text
            applyAttributedText()
          }
          .onChange(of: text) { oldValue, newValue in
            if internalViewModel.text != newValue {
              internalViewModel.text = newValue
              internalViewModel.processTextChange()
              applyAttributedText()
            }
          }

        if internalViewModel.text.isEmpty {
          Text("Type @ to mention someone...")
            .foregroundColor(Color(.placeholderText))
            .padding(8)
            .allowsHitTesting(false)
        }
      }
      //      .frame(height: 150)
      .border(Color.gray.opacity(0.3))

      if internalViewModel.isShowingSuggestions {
        suggestionView
      }
    }
  }

  private var suggestionView: some View {
    ScrollView {
      suggestionContent
    }
    .frame(height: calculateHeight())
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
  }

  private var suggestionContent: some View {
    LazyVStack(alignment: .leading, spacing: 8) {
      ForEach(internalViewModel.mentionSuggestions, id: \.userId) { user in
        suggestionRow(for: user)
      }
    }
    .padding(8)
  }

  private func suggestionRow(for user: User) -> some View {
    HStack {
      Text("@\(user.username)")
        .fontWeight(.medium)
      Text("• \(user.name ?? user.username)")
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .cornerRadius(4)
    .onTapGesture {
      internalViewModel.selectUser(user)
      text = internalViewModel.text
      onTextChange?(internalViewModel.text)
    }
  }

  private func calculateHeight() -> CGFloat {
    return min(CGFloat(internalViewModel.mentionSuggestions.count * 44), 180)
  }

  private func applyAttributedText() {
    guard let textView = findTextView() else { return }
    textView.attributedText = internalViewModel.attributedText
  }

  private func findTextView() -> UITextView? {
    let mirror = Mirror(reflecting: TextEditor(text: $internalViewModel.text))
    let textViewFinder = TextViewFinder()
    return textViewFinder.findTextView(from: mirror)
  }
}

class TextViewFinder {
  func findTextView(from mirror: Mirror) -> UITextView? {
    for child in mirror.children {
      if let textView = child.value as? UITextView {
        return textView
      }

      if let childMirror = Mirror(reflecting: child.value).children.first {
        if let textView = findTextView(
          from: Mirror(reflecting: childMirror.value)
        ) {
          return textView
        }
      }
    }
    return nil
  }
}

//struct ContentView: View {
//  @StateObject private var viewModel = MentionViewModel()
//  @State private var text = "sample text"
//
//  var body: some View {
//    VStack(spacing: 20) {
//      Text("Mention Demo")
//        .font(.headline)
//
//      MentionTextEditor(text: $)
//
//      Text("Try typing @ to see username suggestions")
//        .font(.caption)
//        .foregroundColor(.secondary)
//    }
//    .padding()
//  }
//}

#Preview {
  @Previewable @State var text = "sample text"

  MentionTextEditor(text: $text)
    .padding()
}
