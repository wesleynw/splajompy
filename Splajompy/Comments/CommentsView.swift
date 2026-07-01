import SwiftUI

struct CommentsView: View {
  var postId: Int
  var postManager: PostStore

  @State private var viewModel: ViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var cursorY: CGFloat = 0
  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()

  init(
    postId: Int,
    postManager: PostStore,
  ) {
    self.postId = postId
    _viewModel = State(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    self.postManager = postManager
  }

  init(
    postId: Int,
    postManager: PostStore,
    viewModel: ViewModel,
  ) {
    self.postId = postId
    _viewModel = State(wrappedValue: viewModel)
    self.postManager = postManager
  }

  var body: some View {
    VStack {
      Text("Comments")
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(SJFont.title3)
        .padding()

      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          .padding()
          .frame(maxWidth: .infinity)
          #if os(macOS)
            .controlSize(.small)
          #endif
      case .loaded(let comments):
        if comments.isEmpty {
          noCommentView
        } else {
          let rows = ForEach(comments, id: \.commentId) { comment in
            CommentRow(
              comment: comment,
              isInSheet: false,
              toggleLike: {
                viewModel.toggleLike(for: comment)
              },
              deleteComment: {
                Task {
                  await viewModel.deleteComment(comment)
                  postManager.updatePost(id: postId) { post in
                    post.commentCount -= 1
                  }
                }
              }
            )
          }
          VStack(spacing: 0) {
            rows
          }
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          source: "CommentsView",
          onRetry: { viewModel.loadComments() }
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .alert(
      "Error submitting comment",
      isPresented: $viewModel.showError,
      actions: {
        Button("OK") {
          viewModel.showError = false
        }
      }
    ) {
      Text(
        viewModel.errorMessage
          ?? "An error occurred while submitting your comment."
      )
    }
    .onOpenURL { url in
      return
    }
  }

  private var noCommentView: some View {
    VStack {
      Image("snail-sleeping")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 280, height: 200)

      Text("No comments")
        .font(SJFont.title3)
        .foregroundStyle(.secondary)
    }
    .padding(.bottom, 40)
  }
}

#Preview {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  NavigationStack {
    CommentsView(
      postId: 1,
      postManager: postManager,
      viewModel: mockViewModel
    )
    .environment(AuthManager())
  }
}

#Preview("Loading") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Error(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}
