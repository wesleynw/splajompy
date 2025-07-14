import SwiftUI

struct HomeView: View {
  @State private var isShowingNewPostView = false
  @StateObject private var viewModel: FeedViewModel
  @EnvironmentObject var authManager: AuthManager
  @ObservedObject var postManager: PostManager

  @AppStorage("mindlessMode") private var mindlessMode: Bool = false
  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all

  init(feedType: FeedType = .all, postManager: PostManager) {
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: FeedViewModel(feedType: feedType, postManager: postManager)
    )
  }

  var body: some View {
    mainContent
      .navigationTitle(selectedFeedType == .mutual ? "Home" : "Explore")
      .toolbarTitleMenu {
        Button("Home") {
          selectedFeedType = .mutual
        }
        Button("Explore") {
          selectedFeedType = .all
        }
      }
      .toolbar {
        #if os(iOS)
          addPostToolbarItem
        #endif
      }
      .task {
        viewModel.feedType = selectedFeedType
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
          postList(posts: viewModel.posts)
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.loadPosts(reset: true) }
        )
      }
    }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #else
      .contentMargins(.horizontal, 40, for: .scrollContent)
      .safeAreaPadding(.horizontal, 20)
    #endif
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

  private func postList(posts: [DetailedPost]) -> some View {
    Group {
      if mindlessMode {
        GeometryReader { proxy in
          ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
              ForEach(Array(posts.enumerated()), id: \.element.post.postId) {
                index,
                post in
                ReelsPostView(
                  post: post,
                  postManager: postManager,
                  onLikeButtonTapped: { viewModel.toggleLike(on: post) },
                  onPostDeleted: { viewModel.deletePost(on: post) },
                  onCommentsButtonTapped: {
                    // Handle comments
                  }
                )
                .environmentObject(authManager)
                .containerRelativeFrame([.horizontal, .vertical])
                .padding(.bottom, proxy.safeAreaInsets.bottom / 2)
                .onAppear {
                  handlePostAppear(post: post)
                }
              }

              if viewModel.isLoadingMore {
                ProgressView()
                  .containerRelativeFrame([.horizontal, .vertical])
                  .padding(.bottom, proxy.safeAreaInsets.bottom / 2)
                  .background(Color.black)
              }
            }
            .scrollTargetLayout()
          }
          .scrollTargetBehavior(.paging)
          .scrollIndicators(.hidden)
          .refreshable {
            await viewModel.loadPosts(reset: true)
          }
        }
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(posts.enumerated()), id: \.element.post.postId) {
              index,
              post in
              VStack {
                postRow(post: post)
                  .transition(.opacity)
              }
              .geometryGroup()
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
    }
  }

  private func postRow(post: DetailedPost) -> some View {
    PostView(
      post: post,
      postManager: postManager,
      showAuthor: true,
      onLikeButtonTapped: { viewModel.toggleLike(on: post) },
      onPostDeleted: { viewModel.deletePost(on: post) }
    )
    .environmentObject(authManager)
    .onAppear {
      handlePostAppear(post: post)
    }
  }

  private func handlePostAppear(post: DetailedPost) {
    if case .loaded(let currentPostIds) = viewModel.state,
      post.id == currentPostIds.last && viewModel.canLoadMore
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
