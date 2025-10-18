import SwiftUI

struct StandalonePostView: View {
  let postId: Int
  @ObservedObject var postManager: PostManager

  @StateObject private var viewModel: ViewModel
  @StateObject private var commentsViewModel: CommentsView.ViewModel
  @State private var postState: PostState = .idle
  @FocusState private var isCommentFocused: Bool
  @Environment(\.dismiss) private var dismiss
  @Environment(\.navigationNamespace) private var navigationNamespace

  init(postId: Int, postManager: PostManager) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId, postManager: postManager))
    _commentsViewModel = StateObject(
      wrappedValue: CommentsView.ViewModel(postId: postId, postManager: postManager))
  }

  var body: some View {
    ScrollView {
      switch postState {
      case .idle:
        Color.clear
      case .loading:
        ProgressView()
      case .loaded:
        if let detailedPost = postManager.getPost(id: postId) {
          VStack {
            PostView(
              post: detailedPost,
              postManager: postManager,
              showAuthor: true,
              isStandalone: true,
              onLikeButtonTapped: { viewModel.toggleLike() },
              onPostDeleted: {
                Task {
                  await postManager.deletePost(id: postId)
                  dismiss()
                }
              }
            )
            CommentsView(
              postId: postId,
              postManager: postManager,
              viewModel: commentsViewModel,
              isInSheet: false,
              showInput: false
            )
          }
        } else {
          ErrorScreen(
            errorString: "The post you're looking for doesn't exist or has been removed.",
            onRetry: { await reloadPost() }
          )
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await reloadPost() }
        )
      }
    }
    .onTapGesture {
      isCommentFocused = false
    }
    .refreshable(action: {
      Task { await loadPost() }
    })
    .task {
      await reloadPost()
    }
    .navigationTitle("Post")
    .modifier(
      OptionalNavigationTransitionModifier(
        sourceID: "post-\(postId)",
        namespace: navigationNamespace
      )
    )
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .modifier(
        CommentInputAccessoryModifier(
          commentsViewModel: commentsViewModel,
          isFocused: _isCommentFocused.projectedValue
        ))
    #endif
  }

  private func loadPost() async {
    if postManager.getPost(id: postId) != nil {
      postState = .loaded(postId)
      return
    }

    postState = .loading
    await postManager.loadPost(id: postId)

    if postManager.getPost(id: postId) != nil {
      postState = .loaded(postId)
    } else {
      postState = .failed(NSError(domain: "PostNotFound", code: 404))
    }
  }

  private func reloadPost() async {
    // Check if post is already cached
    if postManager.getPost(id: postId) != nil {
      postState = .loaded(postId)
      return
    }

    postState = .loading
    await postManager.loadPost(id: postId)

    if postManager.getPost(id: postId) != nil {
      postState = .loaded(postId)
    } else {
      postState = .failed(NSError(domain: "PostNotFound", code: 404))
    }
  }
}

#if os(iOS)
  struct CommentInputAccessoryModifier: ViewModifier {
    @ObservedObject var commentsViewModel: CommentsView.ViewModel
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
      content
        .safeAreaInset(edge: .bottom) {
          CommentInputView(
            text: $commentsViewModel.text,
            cursorPosition: $commentsViewModel.cursorPosition,
            isSubmitting: $commentsViewModel.isSubmitting,
            isFocused: isFocused,
            onSubmit: {
              let result = await commentsViewModel.submitComment(
                text: commentsViewModel.text.string)
              if result {
                commentsViewModel.resetInputState()
              }
              return result
            }
          )
        }
    }
  }
#endif
