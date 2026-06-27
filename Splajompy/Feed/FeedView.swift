import PostHog
import SwiftUI

struct FeedView: View {
  @State private var isShowingNewPostView: Bool = false
  @State private var viewModel: FeedViewModel

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
          await viewModel.loadPosts(reset: true)
        }
      }
      .sheet(isPresented: $isShowingNewPostView) {
        NewPostView(
          onPostCreated: {
            Task {
              await viewModel.loadPosts(reset: true)
            }
          }
        )
        .postHogScreenView()
        .interactiveDismissDisabled()
      }
      .sensoryFeedback(.selection, trigger: isShowingNewPostView)
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(iOS)
              .topBarLeading
            #else
              .automatic
            #endif
          }()
        ) {
          FeedTypeToggle(selectedFeedType: $selectedFeedType)
        }

        #if os(macOS)
          ToolbarItem {
            Spacer()
          }
        #endif

        ToolbarItem(
          placement: {
            #if os(iOS)
              .topBarTrailing
            #else
              .automatic
            #endif
          }()
        ) {
          Button(action: { isShowingNewPostView = true }) {
            Image(systemName: "plus")
          }
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
    case .loaded(let posts):
      if posts.isEmpty {
        emptyMessage
      } else {
        postList(posts: posts)
      }
    case .failed(let error):
      ErrorScreen(
        errorString: error.localizedDescription,
        source: "FeedView",
        onRetry: {
          await viewModel.loadPosts(preserveCurrentState: true, reset: true)
        }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func postList(posts: [ObservablePost]) -> some View {
    ScrollView(.vertical) {
      LazyVStack(spacing: 0) {
        ForEach(Array(posts.enumerated()), id: \.element.id) {
          index,
          post in

          PostView(
            post: post,
            showAuthor: true,
            postManager: postManager,
            onLikeButtonTapped: {
              Task { await viewModel.toggleLike(on: post) }
            },
            onPostDeleted: { viewModel.deletePost(on: post) }
          )
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
          Divider()
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
        await viewModel.loadPosts(preserveCurrentState: true, reset: true)
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
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }
}
