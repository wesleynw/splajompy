import SwiftUI

struct CommentsContainerView: View {
  var postId: Int
  var postManager: PostStore
  var scrollProxy: ScrollViewProxy?

  @State private var viewModel: ViewModel

  init(
    postId: Int,
    postManager: PostStore,
    scrollProxy: ScrollViewProxy? = nil,
  ) {
    self.postId = postId
    _viewModel = State(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    self.postManager = postManager
    self.scrollProxy = scrollProxy
  }

  init(
    postId: Int,
    postManager: PostStore,
    scrollProxy: ScrollViewProxy? = nil,
    viewModel: ViewModel,
  ) {
    self.postId = postId
    _viewModel = State(wrappedValue: viewModel)
    self.postManager = postManager
    self.scrollProxy = scrollProxy
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
        VStack(spacing: 0) {
          ForEach(comments) { comment in
            CommentView(
              comment: comment,
              onToggleLike: { comment in viewModel.toggleLike(for: comment)
              },
              onDelete: { commentId in
                Task { await viewModel.deleteComment(comment) }
              },
              onAppear: { comment in
                guard viewModel.pendingScrollCommentId == comment.commentId
                else { return }
                viewModel.pendingScrollCommentId = nil
                withAnimation {
                  scrollProxy?.scrollTo(
                    comment.commentId,
                    anchor: viewModel.commentSortOrder == "Oldest First"
                      ? .bottom : .top
                  )
                }
              },
              onCommentReply: { viewModel.stageCommentReply(to: comment) }
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
          if comments.isEmpty {
            noCommentView
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
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  NavigationStack {
    CommentsContainerView(
      postId: 1,
      postManager: postManager,
      viewModel: mockViewModel
    )
    .environment(AuthManager())
  }
}

#Preview("Loading") {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("No Comments") {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("Error") {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Error(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("nested comments") {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 3,
    service: MockCommentService(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  NavigationStack {
    CommentsContainerView(
      postId: 3,
      postManager: postManager,
      viewModel: mockViewModel
    )
    .environment(AuthManager())
    .modify {
      if #available(anyAppleOS 27, *) {
        $0.swipeActionsContainer()
      }
    }
  }
}
