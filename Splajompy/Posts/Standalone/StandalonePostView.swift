import SwiftUI

struct StandalonePostView: View {
  let postId: Int
  var postManager: PostStore

  @State private var viewModel: ViewModel
  @State private var commentsViewModel: CommentsView.ViewModel
  @State private var postState: PostState = .idle
  @Environment(\.dismiss) private var dismiss

  init(postId: Int, postManager: PostStore) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = State(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    _commentsViewModel = State(
      wrappedValue: CommentsView.ViewModel(
        postId: postId,
        postManager: postManager
      )
    )
  }

  var body: some View {
    ScrollView {
      Group {
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
              errorString:
                "The post you're looking for doesn't exist or has been removed.",
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
      #if os(macOS)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
      #endif
    }
    .refreshable(action: {
      Task { await loadPost() }
    })
    .task {
      await reloadPost()
    }
    .navigationTitle("Post")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .modify {
        if #available(iOS 26, *) {
          $0.safeAreaBar(edge: .bottom) {
            CommentInputViewConstructor(
              commentsViewModel: commentsViewModel
            )
          }
        } else {
          $0.safeAreaInset(edge: .bottom) {
            CommentInputViewConstructor(
              commentsViewModel: commentsViewModel
            )
          }
        }
      }
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

#Preview {
  StandalonePostView(
    postId: 2001,
    postManager: PostStore(postService: MockPostService())
  )
  .environment(AuthManager())
}
