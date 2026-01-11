import PostHog
import SwiftUI

struct MainFeedView: View {
  @State private var isShowingNewPostView = false
  @State private var isShowingWrappedView: Bool = false
  @State private var viewModel: FeedViewModel
  @StateObject private var wrappedViewModel: WrappedViewModel =
    WrappedViewModel()
  @EnvironmentObject var authManager: AuthManager
  @ObservedObject var postManager: PostManager

  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all
  @AppStorage("hasViewedWrapped") private var hasViewedWrapped: Bool = false

  init(postManager: PostManager) {
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
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(iOS)
              .topBarLeading
            #else
              .principal
            #endif
          }()
        ) {
          Menu {
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
              selectedFeedType = .following
            } label: {
              HStack {
                Text("Following")
                if selectedFeedType == .following {
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
          } label: {
            HStack {
              Text("Splajompy")
                .font(.title2)
                .fontWeight(.black)

              #if os(iOS)  // this feels kind of stupid. the mac os includes the chevron automatically
                Image(systemName: "chevron.down")
                  .font(.caption)
              #endif
            }
            .tint(.primary)
          }
          .buttonStyle(.plain)
          .menuIndicator(.visible)
        }
      }
      .onAppear {
        if case .idle = viewModel.state {
          Task {
            await viewModel.loadPosts()
          }
        }

        if PostHogSDK.shared.isFeatureEnabled("rejomp-2025-prompt")
          && !hasViewedWrapped
        {
          Task {
            await wrappedViewModel.loadEligibility()
            if case .loaded(let eligible) = wrappedViewModel.eligibility {
              isShowingWrappedView = eligible
            }
          }
        }
      }
      .onChange(of: selectedFeedType) { _, newFeedType in
        Task {
          viewModel.feedType = newFeedType
          await viewModel.loadPosts(reset: true, useLoadingState: true)
        }
      }
      #if os(iOS)
        .fullScreenCover(isPresented: $isShowingWrappedView) {
          WrappedIntroView()
        }
        .sheet(isPresented: $isShowingNewPostView) {
          newPostSheet
        }
        .toolbar {
          addPostToolbarItem
        }
      #endif
      #if os(macOS)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              Task {
                await viewModel.loadPosts(reset: true)
              }
            } label: {
              if case .loading = viewModel.state {
                ProgressView()
              } else {
                Label("Refresh", systemImage: "arrow.clockwise")
              }
            }
          }
        }
      #endif
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
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
    .environmentObject(authManager)
    .refreshable {
      await viewModel.loadPosts(reset: true)
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
