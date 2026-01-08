import SwiftUI

#if os(iOS)
  struct CommentInputView: View {
    @Binding var text: NSAttributedString
    @Binding var cursorPosition: Int
    @Binding var isSubmitting: Bool
    @FocusState.Binding var isFocused: Bool

    @StateObject private var mentionViewModel = MentionTextEditor.MentionViewModel()
    @State private var cursorY: CGFloat = 0

    var onSubmit: () async -> Bool

    var body: some View {
      VStack(spacing: 0) {
        Divider()

        HStack(alignment: .bottom, spacing: 8) {
          MentionTextEditor(
            text: $text,
            viewModel: mentionViewModel,
            cursorY: $cursorY,
            cursorPosition: $cursorPosition,
            isCompact: true
          )
          .focused($isFocused)

          Button(action: {
            Task {
              _ = await onSubmit()
            }
          }) {
            if isSubmitting {
              ProgressView()
                .frame(width: 32, height: 32)
            } else {
              Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
            }
          }
          .disabled(
            text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || isSubmitting
          )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
      }
      .overlay(alignment: .topLeading) {
        if mentionViewModel.isShowingSuggestions {
          MentionTextEditor.suggestionView(
            suggestions: mentionViewModel.mentionSuggestions,
            isLoading: mentionViewModel.isLoading,
            onInsert: { user in
              let result = mentionViewModel.insertMention(
                user,
                in: text,
                at: cursorPosition
              )
              text = result.text
              cursorPosition = result.newCursorPosition
            }
          )
          .offset(x: 20, y: cursorY + 38)
          .padding(.horizontal, 16)
          .animation(.default, value: mentionViewModel.isShowingSuggestions)
        }
      }
    }
  }
#endif
