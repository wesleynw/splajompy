import SwiftUI

struct HomeView: View {
  @State private var filterState = FilterState()
  @State private var isShowingNewPostView = false
  @StateObject private var viewModel: FeedViewModel
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject var authManager: AuthManager

  init() {
    let savedState = UserDefaults.standard.data(forKey: "feedFilterState")
    let decodedState: FilterState

    if let savedState = savedState,
      let decoded = try? JSONDecoder().decode(
        FilterState.self,
        from: savedState
      )
    {
      decodedState = decoded
    } else {
      decodedState = FilterState()
    }

    _filterState = State(initialValue: decodedState)
    _viewModel = StateObject(
      wrappedValue: FeedViewModel(
        feedType: decodedState.mode == .all ? .all : .home,
        service: MockPostService()
      )
    )
  }

  private func saveFilterState(_ state: FilterState) {
    if let encoded = try? JSONEncoder().encode(state) {
      UserDefaults.standard.set(encoded, forKey: "feedFilterState")
    }
  }

  var body: some View {
    mainContent
      .id(filterState.mode)
      .toolbar {
        logoToolbarItem
        addPostToolbarItem
      }
      .onAppear {
        Task {
          await viewModel.loadPosts()
        }
      }
      .sheet(isPresented: $isShowingNewPostView) {
        newPostSheet
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    VStack {
      switch viewModel.state {
      case .idle:
        loadingPlaceholder
      case .loading:
        loadingPlaceholder
      case .loaded(let posts):
        if posts.isEmpty {
          emptyMessage
        } else {
          postList(posts: posts)
        }
      case .failed(let error):
        errorView(error: error)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private var logoToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      Menu {
        allModeButton
        followingModeButton
      } label: {
        HStack(spacing: 4) {
          Image("Full_Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 30)
          Image(systemName: "chevron.down")
            .font(.caption2)
            .foregroundColor(.primary)
        }
      }
    }
  }

  private var filterMenuToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Menu {
        allModeButton
        followingModeButton
      } label: {
        filterMenuLabel
      }
      .menuStyle(BorderlessButtonMenuStyle())
    }
  }

  private var addPostToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { isShowingNewPostView = true }) {
        Image(systemName: "plus")
      }
      .buttonStyle(.plain)
    }
  }

  private var allModeButton: some View {
    Button {
      selectAllMode()
    } label: {
      HStack {
        Text("All")
        if filterState.mode == .all {
          Image(systemName: "checkmark")
        }
      }
    }
  }

  private var followingModeButton: some View {
    Button {
      selectFollowingMode()
    } label: {
      HStack {
        Text("Following")
        if filterState.mode == .following {
          Image(systemName: "checkmark")
        }
      }
    }
  }

  private var filterMenuLabel: some View {
    HStack {
      Text(filterState.mode == .all ? "All" : "Following")
      Image(systemName: "chevron.down")
        .font(.caption)
    }
    .fontWeight(.semibold)
    .foregroundColor(.primary)
    .padding(.vertical, 5)
    .padding(.horizontal, 10)
    .background(menuLabelBackground)
  }

  private var menuLabelBackground: some View {
    RoundedRectangle(cornerRadius: 8)
      .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
      .background(Color.clear)
  }

  private var newPostSheet: some View {
    NewPostView(
      onPostCreated: { Task { await viewModel.loadPosts(reset: true, useLoadingState: true) } }
    )
    .interactiveDismissDisabled()
  }

  private func selectAllMode() {
    withAnimation(.snappy) {
      filterState.mode = .all
      saveFilterState(filterState)
      viewModel.feedType = .all
      Task {
        await viewModel.loadPosts(reset: true)
      }
    }
  }

  private func selectFollowingMode() {
    withAnimation(.snappy) {
      filterState.mode = .following
      saveFilterState(filterState)
      viewModel.feedType = .home
      Task {
        await viewModel.loadPosts(reset: true)
      }
    }
  }

  private func postList(posts: [DetailedPost]) -> some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(Array(posts.enumerated()), id: \.element.post.postId) {
          index,
          post in
          VStack {
            postRow(post: post)
              .id("post-home_\(post.post.postId)_\(index)")
              .transition(.opacity)
          }
        }

        if viewModel.isLoadingMore {
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
      await Task {
        await viewModel.loadPosts(reset: true)
      }.value
    }
    .animation(.easeInOut(duration: 0.2), value: posts.count)
  }

  private func postRow(post: DetailedPost) -> some View {
    PostView(
      post: post,
      showAuthor: true,
      onLikeButtonTapped: { viewModel.toggleLike(on: post) },
      onPostDeleted: { viewModel.deletePost(on: post) }
    )
    .environmentObject(feedRefreshManager)
    .environmentObject(authManager)
    .id("post-home_\(post.post.postId)")
    .onAppear {
      handlePostAppear(post: post)
    }
  }

  private func handlePostAppear(post: DetailedPost) {
    if case .loaded(let currentPosts) = viewModel.state,
      post == currentPosts.last && viewModel.canLoadMore
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

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      VStack {
        Text("There was an error :/")
          .font(.title2)
          .fontWeight(.bold)
        Text(error.localizedDescription)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
      Button {
        Task {
          await viewModel.loadPosts(reset: true)
        }
      } label: {
        HStack {
          Image(systemName: "arrow.clockwise")
          Text("Retry")
        }
      }
      .padding()
      .buttonStyle(.bordered)
      Spacer()
    }
  }

  private var emptyMessage: some View {
    VStack {
      Spacer()
      Text("No posts yet")
        .foregroundColor(.gray)
        .font(.title2)
      Text("Pull down to refresh or check your connection")
        .foregroundColor(.gray)
        .font(.caption)
        .padding(.top, 5)
      Spacer()
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }
}
