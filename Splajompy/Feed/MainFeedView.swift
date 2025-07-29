import SwiftUI

struct MainFeedView: View {
  @State private var isShowingNewPostView = false
  @StateObject private var viewModel: FeedViewModel
  @EnvironmentObject var authManager: AuthManager
  var postManager: PostManager

  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all

  init(postManager: PostManager) {
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: FeedViewModel(feedType: .all, postManager: postManager)
    )
  }

  var body: some View {
    mainContent
      .toolbarTitleMenu {
        Button {
          selectedFeedType = .mutual
        } label: {
          HStack {
            Text("Home")
            if selectedFeedType == .mutual {
              Image(systemName: "checkmark")
            }
          }
        }
        Button {
          selectedFeedType = .all
        } label: {
          HStack {
            Text("All")
            if selectedFeedType == .all {
              Image(systemName: "checkmark")
            }
          }
        }
      }
      .task {
        await viewModel.loadPosts()
      }
      .onChange(of: selectedFeedType) { _, newFeedType in
        Task {
          viewModel.feedType = newFeedType
          await viewModel.loadPosts(reset: true, useLoadingState: true)
        }
      }
      #if os(iOS)
        .sheet(isPresented: $isShowingNewPostView) {
          newPostSheet
        }
        .toolbar {
          addPostToolbarItem
        }
      #endif
  }

  @ViewBuilder
  private var mainContent: some View {
    VStack {
      switch viewModel.state {
      case .idle:
        loadingPlaceholder
      case .loading:
        loadingPlaceholder
      case .loaded(let postIds):
        if postIds.isEmpty {
          emptyMessage
        } else {
          postList
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.loadPosts(reset: true) }
        )
      }
    }
  }

  private var addPostToolbarItem: some ToolbarContent {
    ToolbarItem(
      placement: {
        #if os(iOS)
          .navigationBarTrailing
        #else
          .primaryAction
        #endif
      }()
    ) {
      Button(action: { isShowingNewPostView = true }) {
        Image(systemName: "plus")
      }
      .buttonStyle(.plain)
    }
  }

  #if os(iOS)
    private var newPostSheet: some View {
      NewPostView(
        onPostCreated: {
          Task { await viewModel.loadPosts(reset: true, useLoadingState: true) }
        }
      )
      .interactiveDismissDisabled()
    }
  #endif

  private var postList: some View {
    Group {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(viewModel.posts.indices, id: \.self) { index in
            let post = viewModel.posts[index]
            VStack {
              postRow(post: post, index: index)
            }
          }

          if viewModel.canLoadMore {
            HStack {
              Spacer()
              ProgressView()
                .padding()
              Spacer()
            }
          }
        }
      }
      .refreshable {
        await viewModel.loadPosts(reset: true)
      }
    }
  }

  private func postRow(post: DetailedPost, index: Int) -> some View {
    PostView(
      post: post,
      postManager: postManager,
      showAuthor: true,
      onLikeButtonTapped: { viewModel.toggleLike(on: post) },
      onPostDeleted: { viewModel.deletePost(on: post) }
    )
    .environmentObject(authManager)
    //    .onAppear {
    //      handlePostAppear(post: post, index: index)
    //    }
  }

  private func handlePostAppear(post: DetailedPost, index: Int) {
    if case .loaded(let currentPostIds) = viewModel.state,
      index >= currentPostIds.count - 3 && viewModel.canLoadMore
        && !viewModel.isLoadingMore
    {
      Task {
        await viewModel.loadPosts()
      }
    }
  }

  private var loadingPlaceholder: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
        .padding()
      Spacer()
    }
  }

  private var emptyMessage: some View {
    VStack {
      Spacer()
      Text("No posts yet.")
        .font(.title3)
        .fontWeight(.bold)
        .padding(.top, 40)
      Text("Here's where you'll see posts from others.")
        .padding()
      Button {
        Task { await viewModel.loadPosts(reset: true) }
      } label: {
        HStack {
          if case .loading = viewModel.state {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Image(systemName: "arrow.clockwise")
          }
          Text("Reload")
        }
      }
      .padding()
      .buttonStyle(.bordered)
      Spacer()
    }
  }
}
