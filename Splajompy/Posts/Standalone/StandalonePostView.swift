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
    let handlePostDeleted: () -> Void = {  // TODO: wtf is this?
      Task {
        await postManager.deletePost(id: postId)
        dismiss()
      }
    }

    ScrollView {
      if case .loaded(let post) = viewModel.state {
        VStack {
          PostView(
            post: post,
            showAuthor: true,
            isStandalone: true,
            postManager: postManager,
            onLikeButtonTapped: { viewModel.toggleLike() },
            onPostDeleted: handlePostDeleted
          )

          CommentsView(
            postId: postId,
            postManager: postManager,
            viewModel: commentsViewModel,
          )
        }
        #if os(macOS)
          .frame(maxWidth: 600)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 200)
        #endif
      }
    }
    .overlay {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          #if os(macOS)
            .controlSize(.small)
          #endif
      case .loaded:
        EmptyView()
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          source: "StandalonePostView",
          onRetry: {
            async let post: () = viewModel.load()
            async let comments: () = commentsViewModel.loadComments()

            let _ = await (post, comments)
          }
        )
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .refreshable {
      async let post: () = await viewModel.load(resetLoadingState: false)
      async let comments: () = await commentsViewModel.loadComments(
        useLoadingState: false
      )

      let _ = await (post, comments)
      NotificationCenter.default.post(name: .userDidRefreshFeed, object: nil)
    }
    .task {
      await viewModel.load()
    }
    .pageTitle("Post")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        let post: ObservablePost? =
          if case .loaded(let p) = viewModel.state { p } else { nil }
        PostActionMenu(
          post: post,
          showAuthor: true,
          onPostDeleted: handlePostDeleted,
          onPostPinned: {},
          onPostUnpinned: {}
        ) {
          Label("More", systemImage: "ellipsis.circle")
        }
      }
    }
    .modify {
      if #available(iOS 26, macOS 26, *) {
        $0.safeAreaBar(edge: .bottom) {
          CommentInputView(viewModel: commentsViewModel)
        }
      } else {
        $0.safeAreaInset(edge: .bottom) {
          CommentInputView(viewModel: commentsViewModel)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    StandalonePostView(
      postId: 4315,
      postManager: PostStore(postService: MockPostService())
    )
    .environment(AuthManager())
  }
}
