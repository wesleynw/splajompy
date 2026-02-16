import PostHog
import SwiftUI

/// Primary view in the app, displays an endless feed of posts.
struct FeedView: View {
  @State private var isShowingNewPostView: Bool = false
  @State private var viewModel: FeedViewModel
  @Environment(AuthManager.self) private var authManager

  var postManager: PostStore

  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all

  init(postManager: PostStore) {
    self.postManager = postManager
    _viewModel = State(
      wrappedValue: FeedViewModel(feedType: .all, postManager: postManager)
    )
  }

  var body: some View {
    mainContent
      #if os(macOS)
        .toolbar(removing: .title)
      #endif
      .onAppear {
        if case .idle = viewModel.state {
          Task {
            await viewModel.loadPosts(reset: true)
          }
        }
      }
      .onChange(of: selectedFeedType) { _, newFeedType in
        PostHogSDK.shared.capture("feed_type_changed")
        Task {
          viewModel.feedType = newFeedType
          await viewModel.loadPosts(reset: true, useLoadingState: true)
        }
      }
      .sheet(isPresented: $isShowingNewPostView) {
        newPostSheet
      }
      .toolbar {
        FeedTypeToggle(selectedFeedType: $selectedFeedType)

        addPostToolbarItem

        #if os(macOS)
          feedRefreshToolbarItem
        #endif
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        #if os(macOS)
          .controlSize(.small)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ToolbarContentBuilder
  private var addPostToolbarItem: some ToolbarContent {
    #if os(iOS)
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { isShowingNewPostView = true }) {
          Image(systemName: "plus")
        }
      }
    #else
      ToolbarItem(placement: .navigation) {
        Button(action: { isShowingNewPostView = true }) {
          Image(systemName: "plus")
        }
      }
    #endif
  }

  @ToolbarContentBuilder
  private var feedRefreshToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button {
        Task {
          await viewModel.loadPosts(reset: true, useLoadingState: true)
          PostHogSDK.shared.capture("feed_refreshed")
        }
      } label: {
        if case .loading = viewModel.state {
          ProgressView()
            .controlSize(.small)
        } else {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
      }
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

  private var postList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) {
          index,
          post in
          PostView(
            post: post,
            postManager: postManager,
            showAuthor: true,
            onLikeButtonTapped: { viewModel.toggleLike(on: post) },
            onPostDeleted: { viewModel.deletePost(on: post) }
          )
          .geometryGroup()
          .onAppear {
            viewModel.handlePostAppear(at: index)
          }
          #if os(macOS)
            .frame(maxWidth: 600)
          #endif
        }

        if viewModel.canLoadMore {
          HStack {
            Spacer()
            ProgressView()
              #if os(macOS)
                .controlSize(.small)
              #endif
              .padding()
            Spacer()
          }
        } else {
          VStack(spacing: 8) {
            Text("Is that the very first post?")
            Text("What came before that?")
            Text("Nothing at all?")
            HStack(spacing: 4) {
              Text("It always just")
              Text("Splajompy")
                .fontWeight(.black)
            }
          }
          .font(.title3)
          .multilineTextAlignment(.center)
          .padding()
        }
      }
      #if os(macOS)
        .frame(maxWidth: .infinity)
      #endif
    }
    .refreshable {
      await viewModel.loadPosts(reset: true)
      PostHogSDK.shared.capture("feed_refreshed")
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
              #if os(macOS)
                .controlSize(.small)
              #endif
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
