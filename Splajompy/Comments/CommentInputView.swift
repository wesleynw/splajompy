import SwiftUI

struct CommentInputViewConstructor: View {
  @ObservedObject var commentsViewModel: CommentsView.ViewModel
  var isFocused: FocusState<Bool>.Binding

  var body: some View {
    CommentInputView(
      text: $commentsViewModel.text,
      selectedRange: $commentsViewModel.selectedRange,
      isSubmitting: $commentsViewModel.isSubmitting,
      isFocused: isFocused,
      onSubmit: {
        let result = await commentsViewModel.submitComment(
          text: commentsViewModel.text.string
        )
        if result {
          commentsViewModel.resetInputState()
        }
        return result
      }
    )
  }
}

struct CommentInputView: View {
  @Binding var text: NSAttributedString
  @Binding var selectedRange: NSRange
  @Binding var isSubmitting: Bool
  @FocusState.Binding var isFocused: Bool

  @StateObject private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @State private var cursorY: CGFloat = 0

  var onSubmit: () async -> Bool

  var body: some View {
    VStack {
      HStack(alignment: .center) {
        MentionTextEditor(
          text: $text,
          viewModel: mentionViewModel,
          cursorY: $cursorY,
          selectedRange: $selectedRange,
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
          } else {
            Image(systemName: "arrow.up.circle.fill")
          }
        }
        .disabled(
          text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isSubmitting
        )
      }
      .padding()
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
              at: selectedRange
            )
            text = result.text
            selectedRange = result.newSelectedRange
          }
        )
        .offset(x: 20, y: cursorY + 38)
        .padding(.horizontal, 16)
        .animation(.default, value: mentionViewModel.isShowingSuggestions)
      }
    }
  }
}
