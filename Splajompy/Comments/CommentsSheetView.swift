import SwiftUI

struct CommentsSheetView: View {
  var postId: Int
  var postManager: PostStore

  @State private var viewModel: CommentsContainerView.ViewModel
  @Environment(\.dismiss) private var dismiss

  @Namespace private var replyNamespace

  init(
    postId: Int,
    postManager: PostStore,
  ) {
    self.postId = postId
    _viewModel = State(
      wrappedValue: CommentsContainerView.ViewModel(
        postId: postId,
        postManager: postManager
      )
    )
    self.postManager = postManager
  }

  init(
    postId: Int,
    postManager: PostStore,
    viewModel: CommentsContainerView.ViewModel,
  ) {
    self.postId = postId
    _viewModel = State(wrappedValue: viewModel)
    self.postManager = postManager
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          if case .loaded(let comments) = viewModel.state {
            VStack(spacing: 0) {
              ForEach(
                comments.filter {
                  $0.commentId != viewModel.respondingToComment?.commentId
                }
              ) { comment in
                CommentView(
                  comment: comment,
                  replyToComment: viewModel.respondingToComment?.commentId
                    ?? nil,
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
                      proxy.scrollTo(
                        comment.commentId,
                        anchor: viewModel.commentSortOrder == "Oldest First"
                          ? .bottom : .top
                      )
                    }
                  },
                  onCommentReply: {
                    withAnimation {
                      viewModel.stageCommentReply(to: comment)
                    }
                  },
                  replyNamespace: replyNamespace,
                )
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(viewModel.respondingToComment == nil)
          }
        }
        .scrollDisabled(viewModel.respondingToComment != nil)
        .overlay {
          switch viewModel.state {
          case .idle, .loading:
            ProgressView()
          case .loaded(let comments):
            if comments.isEmpty {
              noCommentsView
            }
          case .failed(let error):
            ErrorScreen(
              errorString: error.localizedDescription,
              source: "CommentsView",
              onRetry: { viewModel.loadComments() }
            )
          }
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.safeAreaBar(edge: .bottom) {
              CommentInputView(
                onCommentReplyTap: {
                  if let replyingToComment = viewModel.respondingToComment {
                    withAnimation {
                      proxy.scrollTo(replyingToComment.commentId)
                    }
                  }
                },
                viewModel: viewModel,
                replyNamespace: replyNamespace
              )
            }
          } else {
            $0.safeAreaInset(edge: .bottom) {
              CommentInputView(
                onCommentReplyTap: {
                  if let replyingToComment = viewModel.respondingToComment {
                    withAnimation {
                      proxy.scrollTo(replyingToComment.commentId)
                    }
                  }
                },
                viewModel: viewModel,
                replyNamespace: replyNamespace
              )
            }
          }
        }
      }
      .pageTitle("Comments")
      .interactiveDismissDisabled(
        !viewModel.text.string.trimmingCharacters(
          in: .whitespacesAndNewlines
        ).isEmpty || viewModel.imageSelection != nil
          || viewModel.respondingToComment != nil
      )
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26, *) {
              Button(role: .close, action: { dismiss() })
            } else {
              Button("Close") {
                dismiss()
              }
              .buttonStyle(.plain)
            }
          }
        #endif
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
      dismiss()
    }
    .presentationDragIndicator(.visible)
  }

  private var noCommentsView: some View {
    VStack {
      Image("snail-sleeping")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 280, height: 200)

      Text("No comments")
        .font(SJFont.title3)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsSheetView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("Loading") {
  let mockViewModel = CommentsContainerView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsSheetView(
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

  CommentsSheetView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
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
