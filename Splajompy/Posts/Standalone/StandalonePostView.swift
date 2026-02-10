import PostHog
import SwiftUI

struct StandalonePostView: View {
  let postId: Int
  var postManager: PostStore

  @State private var viewModel: ViewModel
  @State private var commentsViewModel: CommentsView.ViewModel
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
        switch viewModel.state {
        case .idle:
          ProgressView()
        case .loading:
          ProgressView()
        case .loaded(let post):
          VStack {
            PostView(
              post: post,
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
        case .failed(let error):
          ErrorScreen(
            errorString: error.localizedDescription,
            onRetry: {
              async let post: () = viewModel.load()
              async let comments: () = commentsViewModel.loadComments()

              let _ = await (post, comments)
            }
          )
        }
      }
      #if os(macOS)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
      #endif
    }
    .postHogScreenView()
    .refreshable {
      async let post: () = await viewModel.load(resetLoadingState: false)
      async let comments: () = await commentsViewModel.loadComments()

      let _ = await (post, comments)
    }
    .task {
      await viewModel.load()
    }
    .navigationTitle("Post")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .modify {
      if #available(iOS 26, macOS 26, *) {
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
  }
}

#Preview {
  StandalonePostView(
    postId: 2001,
    postManager: PostStore(postService: MockPostService())
  )
  .environment(AuthManager())
}
