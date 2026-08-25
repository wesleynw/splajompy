import SwiftUI

struct CommentsSheetView: View {
  var postId: Int
  var postManager: PostStore

  @State private var viewModel: CommentsView.ViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var cursorY: CGFloat = 0
  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()

  init(
    postId: Int,
    postManager: PostStore,
    isInSheet: Bool = true,
  ) {
    self.postId = postId
    _viewModel = State(
      wrappedValue: CommentsView.ViewModel(
        postId: postId,
        postManager: postManager
      )
    )
    self.postManager = postManager
  }

  init(
    postId: Int,
    postManager: PostStore,
    viewModel: CommentsView.ViewModel,
  ) {
    self.postId = postId
    _viewModel = State(wrappedValue: viewModel)
    self.postManager = postManager
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        let scrollToNewComment: (Int) -> Void = { newCommentId in
          DispatchQueue.main.async {
            withAnimation {
              proxy.scrollTo(
                newCommentId,
                anchor: viewModel.commentSortOrder == "Oldest First" ? .bottom : .top
              )
            }
          }
        }

        ScrollView {
          if case .loaded(let comments) = viewModel.state {
            if !comments.isEmpty {
              ForEach(comments, id: \.commentId) { comment in
                CommentRow(
                  comment: comment,
                  isInSheet: true,
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
                .id(comment.commentId)
              }
            }
          }
        }
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
              CommentInputView(viewModel: viewModel, onCommentAdded: scrollToNewComment)
            }
          } else {
            $0.safeAreaInset(edge: .bottom) {
              CommentInputView(viewModel: viewModel, onCommentAdded: scrollToNewComment)
            }
          }
        }
      }
      .pageTitle("Comments")
      .interactiveDismissDisabled(
        !viewModel.text.string.trimmingCharacters(
          in: .whitespacesAndNewlines
        ).isEmpty || viewModel.imageSelection != nil
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
  let mockViewModel = CommentsView.ViewModel(
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
  let mockViewModel = CommentsView.ViewModel(
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
  let mockViewModel = CommentsView.ViewModel(
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
