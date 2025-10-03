import SwiftUI

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @State private var cursorPosition: Int = 0
  @State private var cursorY: CGFloat = 0
  @FocusState private var isFocused: Bool

  @StateObject private var viewModel: MentionViewModel

  init(text: Binding<NSAttributedString>) {
    self._text = text
    self._viewModel = StateObject(wrappedValue: MentionViewModel())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        AttributedTextEditor(
          text: $text,
          cursorPosition: $cursorPosition,
          cursorY: $cursorY,
          viewModel: viewModel
        )
        .frame(minHeight: 120)
        .frame(maxWidth: .infinity)
        .focused($isFocused)

        if text.string.isEmpty {
          Text("What's on your mind?")
            .foregroundColor(Color(.placeholderText))
            .padding(8)
        }
      }
      .padding()
      .padding(.bottom, 200)
      .overlay(alignment: .topLeading) {
        if viewModel.isShowingSuggestions {
          suggestionView
            .offset(y: cursorY + 20)
            .animation(.default, value: viewModel.isShowingSuggestions)
        }
      }
    }
    .padding(.horizontal)
    .frame(maxWidth: .infinity)
    .onAppear {
      isFocused = true
    }
  }

  private var suggestionView: some View {
    VStack(spacing: 0) {
      if viewModel.mentionSuggestions.isEmpty {
        Text("No users found")
          .foregroundColor(.gray)
          .frame(height: 44)
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        ForEach(viewModel.mentionSuggestions.prefix(5), id: \.userId) { user in
          suggestionRow(for: user)
          if user.userId != viewModel.mentionSuggestions.prefix(5).last?.userId {
            Divider().opacity(0.4)
          }
        }
      }
    }
    .frame(height: calculateHeight())
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
  }

  private func calculateHeight() -> CGFloat {
    let rowHeight: CGFloat = 44
    let count =
      viewModel.mentionSuggestions.isEmpty
      ? 1 : min(viewModel.mentionSuggestions.count, 5)
    return CGFloat(count) * rowHeight
  }

  private func suggestionRow(for user: User) -> some View {
    HStack {
      Text("@\(user.username)")
        .fontWeight(.medium)
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .onTapGesture {
      let result = viewModel.insertMention(user, in: text, at: cursorPosition)
      text = result.text
      cursorPosition = result.newCursorPosition
    }
  }
}
