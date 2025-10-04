import SwiftUI

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @ObservedObject var viewModel: MentionViewModel
  @Binding var cursorY: CGFloat
  @Binding var cursorPosition: Int

  @State private var contentHeight: CGFloat = 100
  @FocusState private var isFocused: Bool

  init(
    text: Binding<NSAttributedString>,
    viewModel: MentionViewModel,
    cursorY: Binding<CGFloat>,
    cursorPosition: Binding<Int>
  ) {
    self._text = text
    self.viewModel = viewModel
    self._cursorY = cursorY
    self._cursorPosition = cursorPosition
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        AttributedTextEditor(
          text: $text,
          cursorPosition: $cursorPosition,
          cursorY: $cursorY,
          contentHeight: $contentHeight,
          viewModel: viewModel
        )
        .frame(maxWidth: .infinity, minHeight: contentHeight)
        .focused($isFocused)

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
    .onAppear {
      isFocused = true
    }
  }

  static func suggestionView(
    suggestions: [User],
    onInsert: @escaping (User) -> Void
  ) -> some View {
    VStack(spacing: 0) {
      if suggestions.isEmpty {
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
    .frame(height: calculateSuggestionHeight(suggestions: suggestions))
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
    )
  }

  private static func calculateSuggestionHeight(suggestions: [User]) -> CGFloat {
    let rowHeight: CGFloat = 44
    let count = suggestions.isEmpty ? 1 : min(suggestions.count, 5)
    return CGFloat(count) * rowHeight
  }
}
