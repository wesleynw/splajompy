import SwiftUI

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @ObservedObject var viewModel: MentionViewModel
  @Binding var cursorY: CGFloat
  @Binding var cursorPosition: Int
  var isCompact: Bool
  var autoFocusOnAppear: Bool

  @State private var contentHeight: CGFloat
  @FocusState private var isFocused: Bool

  init(
    text: Binding<NSAttributedString>,
    viewModel: MentionViewModel,
    cursorY: Binding<CGFloat>,
    cursorPosition: Binding<Int>,
    isCompact: Bool = false,
    autoFocusOnAppear: Bool = false
  ) {
    self._text = text
    self.viewModel = viewModel
    self._cursorY = cursorY
    self._cursorPosition = cursorPosition
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
          cursorPosition: $cursorPosition,
          cursorY: $cursorY,
          contentHeight: $contentHeight,
          viewModel: viewModel,
          isScrollEnabled: true
        )
        .frame(height: displayHeight)
        .focused($isFocused)
        .onAppear {
          if autoFocusOnAppear {
            self.isFocused = true
          }
        }

        if text.string.isEmpty {
          Text("Add a comment...")
            .foregroundColor(Color(.placeholderText))
            .offset(x: 8, y: 4)
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(Color(.systemBackground))
      .cornerRadius(18)
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(Color(.separator), lineWidth: 0.5)
      )
    } else {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .topLeading) {
          AttributedTextEditor(
            text: $text,
            cursorPosition: $cursorPosition,
            cursorY: $cursorY,
            contentHeight: $contentHeight,
            viewModel: viewModel,
            isScrollEnabled: false
          )
          .frame(maxWidth: .infinity, minHeight: contentHeight)
          .focused($isFocused)
          .onAppear {
            if autoFocusOnAppear {
              self.isFocused = true
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
    onInsert: @escaping (PublicUser) -> Void
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
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
    )
  }
}
