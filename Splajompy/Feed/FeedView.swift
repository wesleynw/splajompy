import PostHog
import SwiftUI

struct FeedView: View {
  @State private var isShowingNewPostView: Bool = false
  @State private var viewModel: FeedViewModel
  @Environment(AuthManager.self) private var authManager

  var postManager: PostStore

  @AppStorage("selectedFeedType") private var selectedFeedType: FeedType = .all

  init(postManager: PostStore) {
    self.postManager = postManager

    let savedFeedType: FeedType
    if let raw = UserDefaults.standard.string(forKey: "selectedFeedType"),
      let feedType = FeedType(rawValue: raw)
    {
      savedFeedType = feedType
    } else {
      savedFeedType = .all
    }

    _viewModel = State(
      wrappedValue: FeedViewModel(
        feedType: savedFeedType,
        postManager: postManager
      )
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
        Task {
          viewModel.feedType = newFeedType
          await viewModel.loadPosts(reset: true, useLoadingState: true)
        }
      }
      .sheet(isPresented: $isShowingNewPostView) {
        NewPostView(
          onPostCreated: {
            Task {
              await viewModel.loadPosts(reset: true, useLoadingState: true)
            }
          }
        )
        .postHogScreenView()
        .interactiveDismissDisabled()
      }
      .toolbar {
        FeedTypeToggle(selectedFeedType: $selectedFeedType)

        #if os(iOS)
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { isShowingNewPostView = true }) {
              Image(systemName: "plus")
            }
          }
        #else
          ToolbarItemGroup(placement: .automatic) {
            Spacer()
            Button(action: { isShowingNewPostView = true }) {
              Image(systemName: "plus")
            }
            Button {
              Task {
                await viewModel.loadPosts(reset: true, useLoadingState: true)
                PostHogSDK.shared.capture("feed_refreshed")
              }
            } label: {
              Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
          }
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
        source: "FeedView",
        onRetry: { await viewModel.loadPosts(reset: true) }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var postList: some View {
    ScrollView(.vertical) {
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
          ProgressView()
            #if os(macOS)
              .controlSize(.small)
            #endif
            .frame(maxWidth: .infinity, alignment: .center)
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
    }
    .refreshable {
      // I don't particularly understand why, but this needs to be wrapped in an unstructured task to avoid task cancellation
      // in some contexts. Previously, if you opened the app switcher while this was loading, it would cancel the task immediately
      // and show an error screen.
      await Task {
        await viewModel.loadPosts(reset: true)
        PostHogSDK.shared.capture("feed_refreshed")
      }.value
    }
  }

  private var emptyMessage: some View {
    VStack {
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
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }
}
