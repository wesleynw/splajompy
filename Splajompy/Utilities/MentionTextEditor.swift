import SwiftUI

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @ObservedObject var viewModel: MentionViewModel
  @Binding var cursorY: CGFloat
  @Binding var selectedRange: NSRange
  var isCompact: Bool
  var autoFocusOnAppear: Bool
  @FocusState var isFocused: Bool

  @State private var contentHeight: CGFloat
  @State private var currentMention: String?

  static let mentionPattern = "@([a-zA-Z0-9_.]+)"

  struct Mention {
    let username: String
    let range: NSRange
  }

  static func extractMentions(from text: String) -> [Mention] {
    guard let regex = try? NSRegularExpression(pattern: mentionPattern) else {
      return []
    }

    let nsString = text as NSString
    let matches = regex.matches(
      in: text,
      range: NSRange(location: 0, length: nsString.length)
    )

    return matches.compactMap { match in
      guard match.numberOfRanges > 1 else { return nil }
      let usernameRange = match.range(at: 1)
      let username = nsString.substring(with: usernameRange)
      return Mention(username: username, range: match.range)
    }
  }

  static func isPositionInMention(in text: String, at position: Int) -> Bool {
    let mentions = extractMentions(from: text)
    return mentions.contains { mention in
      // Cursor must be INSIDE the mention, not at the start
      // If cursor is at mention.range.location (before the @), treat as normal text
      position > mention.range.location
        && position < mention.range.location + mention.range.length
    }
  }

  init(
    text: Binding<NSAttributedString>,
    viewModel: MentionViewModel,
    cursorY: Binding<CGFloat>,
    selectedRange: Binding<NSRange>,
    isCompact: Bool = false,
    autoFocusOnAppear: Bool = false
  ) {
    self._text = text
    self.viewModel = viewModel
    self._cursorY = cursorY
    self._selectedRange = selectedRange
    self.isCompact = isCompact
    self._contentHeight = State(initialValue: 0)
    self.autoFocusOnAppear = autoFocusOnAppear
  }

  var body: some View {
    if isCompact {
      let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
      let textViewInset: CGFloat = 8
      let maxHeight = (lineHeight * 10) + textViewInset
      let minHeight = lineHeight + textViewInset
      let displayHeight = min(max(contentHeight, minHeight), maxHeight)

      ZStack(alignment: .topLeading) {
        AttributedTextEditor(
          text: $text,
          currentMention: $currentMention,
          selectedRange: $selectedRange,
          cursorY: $cursorY,
          contentHeight: $contentHeight,
          isScrollEnabled: true
        )
        .frame(height: displayHeight)
        .focused($isFocused)
        .onAppear {
          if autoFocusOnAppear {
            self.isFocused = true
          }
        }
        .onChange(of: currentMention) { oldValue, newValue in
          if let mention = newValue, !mention.isEmpty {
            viewModel.fetchSuggestions(prefix: mention)
          } else {
            viewModel.clearMentionState()
          }
        }

        if text.string.isEmpty {
          Text("Add a comment...")
            .foregroundColor(Color(.placeholderText))
            .offset(x: 8, y: 4)
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      .modify {
        if #available(iOS 26, *) {
          $0.glassEffect(
            .regular.tint(.clear.opacity(0.15)).interactive(),
            in: RoundedRectangle(cornerRadius: 25))
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .topLeading) {
          AttributedTextEditor(
            text: $text,
            currentMention: $currentMention,
            selectedRange: $selectedRange,
            cursorY: $cursorY,
            contentHeight: $contentHeight,
            isScrollEnabled: false
          )
          .frame(maxWidth: .infinity, minHeight: contentHeight)
          .focused($isFocused)
          .onAppear {
            if autoFocusOnAppear {
              self.isFocused = true
            }
          }
          .onChange(of: currentMention) { oldValue, newValue in
            if let mention = newValue, !mention.isEmpty {
              viewModel.fetchSuggestions(prefix: mention)
            } else {
              viewModel.clearMentionState()
            }
          }

          if text.string.isEmpty {
            Text("What's on your mind?")
              .foregroundColor(Color(.placeholderText))
              .padding(8)
          }
        }
        .padding()
      }
      .padding(.horizontal)
      .frame(maxWidth: .infinity)
    }
  }

  static func suggestionView(
    suggestions: [PublicUser],
    isLoading: Bool = false,
    onInsert: @escaping (PublicUser) -> Void
  ) -> some View {
    VStack(spacing: 0) {
      if isLoading {
        HStack {
          ProgressView()
            .padding(.trailing, 8)
          Text("Searching...")
            .foregroundColor(.gray)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .center)
      } else if suggestions.isEmpty {
        Text("No users found")
          .foregroundColor(.gray)
          .frame(height: 44)
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        ForEach(suggestions.prefix(5), id: \.userId) { user in
          Button {
            onInsert(user)
          } label: {
            HStack {
              Text("@\(user.username)")
                .fontWeight(.medium)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          if user.userId != suggestions.prefix(5).last?.userId {
            Divider().opacity(0.4)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
    )
  }
}

#Preview {
  @Previewable @State var text: NSAttributedString = NSAttributedString(
    string: ""
  )
  @Previewable @State var cursorY: CGFloat = 0
  @Previewable @State var selectedRange: NSRange = NSRange()
  @Previewable @FocusState var isFocused: Bool

  MentionTextEditor(
    text: $text,
    viewModel: MentionTextEditor.MentionViewModel(),
    cursorY: $cursorY,
    selectedRange: $selectedRange,
    isCompact: true
  )
  .padding()
}
