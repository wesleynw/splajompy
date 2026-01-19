import SwiftUI

struct CommentInputViewConstructor: View {
  @State var commentsViewModel: CommentsView.ViewModel

  var body: some View {
    CommentInputView(
      text: $commentsViewModel.text,
      selectedRange: $commentsViewModel.selectedRange,
      isSubmitting: $commentsViewModel.isSubmitting,
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

  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @State private var cursorY: CGFloat = 0

  var onSubmit: () async -> Bool

  var body: some View {
    VStack {
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
        .modify {
          if #available(iOS 26, *) {
            $0.glassEffect(
              .regular.interactive(),
              in: RoundedRectangle(cornerRadius: 15)
            )
          }
        }
        .animation(.default, value: mentionViewModel.isShowingSuggestions)
        .padding(.horizontal)
      }

      HStack(alignment: .center) {
        MentionTextEditor(
          text: $text,
          viewModel: mentionViewModel,
          cursorY: $cursorY,
          selectedRange: $selectedRange,
          isCompact: true
        )

        Button(action: {
          Task {
            _ = await onSubmit()
          }
        }) {
          if isSubmitting {
            ProgressView()
          } else {
            Image(systemName: "arrow.up.circle.fill")
              .font(.title)
          }
        }
        .disabled(
          text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isSubmitting
        )
      }
      .modify {
        if #available(iOS 26, *) {
          $0.padding()
        } else {
          $0
            .padding(8)
            .background(.bar)
            .overlay(alignment: .top) {
              Divider()
            }
        }
      }

    }
  }
}
