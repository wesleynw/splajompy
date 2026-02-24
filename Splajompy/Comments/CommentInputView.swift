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
  @State private var submitButtonWidth: CGFloat = 0

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
          if #available(iOS 26, macOS 26, *) {
            $0.glassEffect(
              .regular.interactive(),
              in: RoundedRectangle(cornerRadius: 15)
            )
          }
        }
        .animation(.default, value: mentionViewModel.isShowingSuggestions)
        .padding(.horizontal)
      }

      HStack(alignment: .bottom) {
        MentionTextEditor(
          text: $text,
          viewModel: mentionViewModel,
          cursorY: $cursorY,
          selectedRange: $selectedRange,
          isCompact: true,
          trailingInset: submitButtonWidth
        )
        .overlay(alignment: .bottomTrailing) {
          Button(action: {
            Task {
              _ = await onSubmit()
            }
          }) {
            if isSubmitting {
              ProgressView()
                .frame(width: 32, height: 32)
                #if os(macOS)
                  .controlSize(.small)
                #endif
            } else {
              Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
            }
          }
          .disabled(
            text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || isSubmitting
          )
          #if os(macOS)
            .buttonStyle(.plain)
          #endif
          .padding(5)
          .onGeometryChange(for: CGFloat.self) {
            $0.size.width
          } action: {
            submitButtonWidth = $0
          }
        }
      }
      .modify {
        if #available(iOS 26, macOS 26, *) {
          $0
            .glassEffect(
              .regular.tint(.clear.opacity(0.15)).interactive(),
              in: RoundedRectangle(cornerRadius: 25)
            )
            .padding()
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
    #if os(macOS)
      .frame(maxWidth: 600)
    #endif
  }
}

#Preview {
  CommentInputViewConstructor(
    commentsViewModel: CommentsView.ViewModel(
      postId: 1,
      postManager: PostStore()
    )
  )
}
