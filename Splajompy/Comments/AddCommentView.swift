import SwiftUI

struct AddCommentSheet: View {
  @ObservedObject var viewModel: CommentsView.ViewModel
  @State private var text = NSAttributedString(string: "")
  @State private var cursorY: CGFloat = 0
  @State private var cursorPosition: Int = 0
  #if os(iOS)
    @StateObject private var mentionViewModel =
      MentionTextEditor.MentionViewModel()
  #endif
  @Environment(\.dismiss) var dismiss
  let postId: Int

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          #if os(iOS)
            MentionTextEditor(
              text: $text,
              viewModel: mentionViewModel,
              cursorY: $cursorY,
              cursorPosition: $cursorPosition
            )
          #endif

          Spacer()
        }
        // to allow mentions overlay to be visible when at bottom of text view
        .padding(.bottom, 250)
        #if os(iOS)
          .overlay(alignment: .topLeading) {
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
              .offset(y: cursorY + 20)
              .padding(.horizontal, 32)
              .animation(.default, value: mentionViewModel.isShowingSuggestions)
            }
          }
        #endif
      }
      #if os(iOS)
        .navigationTitle("Comment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            if #available(iOS 26.0, *) {
              Button(role: .close, action: { dismiss() })
            } else {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark.circle.fill")
                .opacity(0.8)
              }
              .buttonStyle(.plain)
            }
          }

          ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26, *) {
              Button {
                Task {
                  let result = await viewModel.submitComment(text: text.string)
                  if result == true {
                    dismiss()
                  }
                }
              } label: {
                if viewModel.isSubmitting {
                  ProgressView()
                } else {
                  Label("Comment", systemImage: "arrow.up")
                }
              }
              .disabled(
                text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                  .isEmpty
                  || viewModel.isSubmitting
              )
              .buttonStyle(.glassProminent)
            } else {
              Button {
                Task {
                  let result = await viewModel.submitComment(text: text.string)
                  if result == true {
                    dismiss()
                  }
                }
              } label: {
                Image(systemName: "arrow.up.circle.fill")
                .opacity(0.8)
              }
              .disabled(
                text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                  .isEmpty
                  || viewModel.isSubmitting
              )
            }
          }
        }
      #endif
    }
  }
}

#Preview {
  @Previewable @State var showSheet = true

  Color.clear
    .sheet(isPresented: .constant(true)) {
      AddCommentSheet(
        viewModel: CommentsView.ViewModel(
          postId: 1,
          postManager: PostManager()
        ),
        postId: 1
      )
    }
}
