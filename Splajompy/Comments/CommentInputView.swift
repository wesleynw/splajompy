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
        //        Divider()

        HStack(alignment: .bottom, spacing: 8) {
          MentionTextEditor(
            text: $text,
            viewModel: mentionViewModel,
            cursorY: $cursorY,
            cursorPosition: $cursorPosition,
            isCompact: true
          )
          .focused($isFocused)

          if !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(action: {
              Task {
                _ = await onSubmit()
              }
            }) {
              if isSubmitting {
                ProgressView()
                  .frame(width: 32, height: 32)
              } else {
                Image(systemName: "arrow.up")
                  .font(.system(size: 16, weight: .semibold))
              }
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .transition(.scale.combined(with: .move(edge: .trailing)))
          }
        }
        .animation(
          .spring(response: 0.3, dampingFraction: 0.7),
          value: text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        //        .background(Color(uiColor: .systemBackground))
      }
      .overlay(alignment: .bottomLeading) {
        if mentionViewModel.isShowingSuggestions {
          MentionTextEditor.suggestionView(
            suggestions: mentionViewModel.mentionSuggestions,
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
          .padding(.horizontal, 16)
          .padding(.bottom, 60)
          .animation(.default, value: mentionViewModel.isShowingSuggestions)
        }
      }
    }
  }
#endif
