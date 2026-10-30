import SwiftUI

struct CommentsContainerView: View {
  var postId: Int
  var postManager: PostStore
  var replyNamespace: Namespace.ID
  var enableReplySwipeGesture: Bool

  @State private var viewModel: ViewModel

  init(
    postId: Int,
    postManager: PostStore,
    scrollProxy: ScrollViewProxy? = nil,
    replyNamespace: Namespace.ID,
    enableReplySwipeGesture: Bool = false
  ) {
    self.postId = postId
    _viewModel = State(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    self.postManager = postManager
    self.replyNamespace = replyNamespace
    self.enableReplySwipeGesture = enableReplySwipeGesture
  }

  init(
    postId: Int,
    postManager: PostStore,
    scrollProxy: ScrollViewProxy? = nil,
    viewModel: ViewModel,
    replyNamespace: Namespace.ID,
    enableReplySwipeGesture: Bool = false,
  ) {
    self.postId = postId
    _viewModel = State(wrappedValue: viewModel)
    self.postManager = postManager
    self.replyNamespace = replyNamespace
    self.enableReplySwipeGesture = enableReplySwipeGesture
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
          ForEach(
            comments.filter {
              $0.commentId != viewModel.respondingToComment?.commentId
            }
          ) { comment in
            CommentView(
              comment: comment,
              replyToComment: viewModel.respondingToComment?.commentId,
              onToggleLike: { comment in viewModel.toggleLike(for: comment)
              },
              onDelete: { comment in
                Task { await viewModel.deleteComment(comment) }
              },
              onCommentReply: {
                withAnimation {
                  viewModel.stageCommentReply(to: comment)
                }
              },
              enableReplySwipeGesture: enableReplySwipeGesture,
              replyNamespace: replyNamespace,
            )
            .sensoryFeedback(
              .impact,
              trigger: viewModel.respondingToComment?.commentId
            )
          }
          .allowsHitTesting(viewModel.respondingToComment == nil)
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
  @Previewable @Namespace var namespace

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
      viewModel: mockViewModel,
      replyNamespace: namespace
    )
    .environment(AuthManager())
  }
}

#Preview("Loading") {
  @Previewable @Namespace var namespace

  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel,
    replyNamespace: namespace,
  )
  .environment(AuthManager())
}

#Preview("No Comments") {
  @Previewable @Namespace var namespace

  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel,
    replyNamespace: namespace,
  )
  .environment(AuthManager())
}

#Preview("Error") {
  @Previewable @Namespace var namespace

  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Error(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsContainerView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel,
    replyNamespace: namespace,
  )
  .environment(AuthManager())
}

#Preview("nested comments") {
  @Previewable @Namespace var namespace

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
      viewModel: mockViewModel,
      replyNamespace: namespace,
    )
    .environment(AuthManager())
  }
}
