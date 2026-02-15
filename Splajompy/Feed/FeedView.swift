import PostHog
import SwiftUI

struct FeedView: View {
  @State private var isShowingNewPostView = false
  @State private var isShowingWrappedView: Bool = false
  @State private var viewModel: FeedViewModel
  @State private var wrappedViewModel: WrappedViewModel =
    WrappedViewModel()
  @Environment(AuthManager.self) private var authManager
  var postManager: PostStore

  @State private var scrollOffset = CGFloat.zero

  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all
  @AppStorage("hasViewedWrapped") private var hasViewedWrapped: Bool = false

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
        PostHogSDK.shared.capture("feed_type_changed")
        Task {
          viewModel.feedType = newFeedType
          await viewModel.loadPosts(reset: true, useLoadingState: true)
        }
      }
      #if os(iOS)
        .fullScreenCover(isPresented: $isShowingWrappedView) {
          WrappedIntroView()
        }
      #endif
      .sheet(isPresented: $isShowingNewPostView) {
        newPostSheet
      }
      .toolbar {
        feedMenuToolbarItem
        addPostToolbarItem

        #if os(macOS)
          feedRefreshToolbarItem
        #endif
      }
      .modify {
        if #available(iOS 26, *),
          PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
        {
          $0.scrollFadeBackground(scrollOffset: scrollOffset)
        }
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
  private var feedMenuToolbarItem: some ToolbarContent {
    #if os(iOS)
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        ToolbarItem(placement: .topBarLeading) {
          feedMenu
        }
      } else {
        ToolbarItem(placement: .topBarLeading) {
          feedMenu
        }
      }
    #else
      if #available(macOS 26.0, *) {
        ToolbarItem(placement: .principal) {
          feedMenuMac
        }
        .sharedBackgroundVisibility(.hidden)
      } else {
        ToolbarItem(placement: .principal) {
          feedMenuMac
        }
      }
    #endif
  }

  private var feedMenu: some View {
    Menu {
      feedMenuButtons
    } label: {
      HStack {
        Text("Splajompy")
          .font(.title2)
          .fontWeight(.black)

        Image(systemName: "chevron.down")
          .font(.caption)
      }
      .tint(.primary)
    }
    .buttonStyle(.plain)
    .menuIndicator(.visible)
  }

  private var feedMenuMac: some View {
    Menu {
      feedMenuButtons
    } label: {
      HStack {
        Text("Splajompy")
          .font(.title2)
          .fontWeight(.black)
      }
      .tint(.primary)
    }
    .buttonStyle(.plain)
    .menuIndicator(.visible)
  }

  @ViewBuilder
  private var feedMenuButtons: some View {
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
    .modify {
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        $0.scrollFadeEffect(scrollOffset: $scrollOffset)
      }
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
