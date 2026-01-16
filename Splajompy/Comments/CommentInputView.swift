import SwiftUI

struct CommentInputViewConstructor: View {
  @ObservedObject var commentsViewModel: CommentsView.ViewModel

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

  @StateObject private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @State private var cursorY: CGFloat = 0

  var onSubmit: () async -> Bool

  var body: some View {
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
    .overlay(alignment: .top) {
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
            // https://jeffverkoeyen.com/blog/2025/06/11/OffsetButtonsInScrollViews/
            .padding(.top, cursorY + 68)
          }
        }
        .offset(y: -(cursorY + 68))
        .padding(.horizontal)
        .animation(.default, value: mentionViewModel.isShowingSuggestions)
      }
    }
  }
}
