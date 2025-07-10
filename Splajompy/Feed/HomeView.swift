import SwiftUI

struct HomeView: View {
  @State private var isShowingNewPostView = false
  @StateObject private var viewModel = FeedViewModel(feedType: .mutual)
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject var authManager: AuthManager
  @AppStorage("mindlessMode") private var mindlessMode: Bool = false

  var body: some View {
    mainContent
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
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.loadPosts(reset: true) }
        )
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private var logoToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
      Image("Full_Logo")
        .resizable()
        .scaledToFit()
        .frame(height: 30)
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

  private var newPostSheet: some View {
    NewPostView(
      onPostCreated: {
        Task { await viewModel.loadPosts(reset: true, useLoadingState: true) }
      }
    )
    .interactiveDismissDisabled()
  }

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
                  onLikeButtonTapped: { viewModel.toggleLike(on: post) },
                  onPostDeleted: { viewModel.deletePost(on: post) },
                  onCommentsButtonTapped: {
                    // Handle comments
                  }
                )
                .environmentObject(feedRefreshManager)
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
      showAuthor: true,
      onLikeButtonTapped: { viewModel.toggleLike(on: post) },
      onPostDeleted: { viewModel.deletePost(on: post) }
    )
    .environmentObject(feedRefreshManager)
    .environmentObject(authManager)
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
