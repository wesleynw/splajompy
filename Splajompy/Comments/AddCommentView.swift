import SwiftUI

struct AddCommentSheet: View {
  @ObservedObject var viewModel: CommentsView.ViewModel
  @State private var text = NSAttributedString(string: "")
  @Environment(\.dismiss) var dismiss
  let postId: Int
  let postManager: PostManager

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button("Cancel") {
          dismiss()
        }

        Spacer()

        Button("Comment") {
          submitComment()
        }
        .disabled(
          text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .fontWeight(.semibold)
        .font(.headline)
      }
      .padding([.top, .leading, .trailing])

      #if os(iOS)
        MentionTextEditor(text: $text, showSuggestionsOnTop: false)
      #endif

      Spacer()
    }
    .presentationDragIndicator(.visible)
  }

  private func submitComment() {
    let commentText = text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !commentText.isEmpty else { return }

    Task {
      await viewModel.submitComment(text: commentText)

      postManager.updatePost(id: postId) { post in
        post.commentCount += 1
      }

      await MainActor.run {
        dismiss()
      }
    }
  }
}

#Preview {
  @Previewable @State var showSheet = true

  Color.clear
    .sheet(isPresented: .constant(true)) {
      AddCommentSheet(
        viewModel: CommentsView.ViewModel(postId: 1),
        postId: 1,
        postManager: PostManager()
      )
    }
}
