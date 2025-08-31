import SwiftUI

struct StandalonePostView: View {
  let postId: Int
  @ObservedObject var postManager: PostManager

  @StateObject private var viewModel: ViewModel
  @State private var postState: PostState = .idle
  @Environment(\.dismiss) private var dismiss

  init(postId: Int, postManager: PostManager) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId, postManager: postManager))
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
            CommentsView(postId: postId, isShowingInSheet: false, postManager: postManager)
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
    .refreshable(action: {
      Task { await loadPost() }
    })
    .task {
      await reloadPost()
    }
    .navigationTitle("Post")
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
