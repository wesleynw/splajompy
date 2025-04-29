import SwiftUI

enum Route: Hashable {
  case profile(id: String, username: String)
}

struct FeedView<Header: View>: View {
  var feedType: FeedType
  var userId: Int?

  // this is a hack to insert something at the top of a scroll view so we don't have nested scrollviews
  let header: Header

  @State var path = NavigationPath()

  @StateObject private var viewModel: ViewModel
  @EnvironmentObject var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject var authManager: AuthManager

  init(feedType: FeedType, userId: Int? = nil) where Header == EmptyView {
    self.feedType = feedType
    self.userId = userId
    self.header = EmptyView()
    _viewModel = StateObject(
      wrappedValue: ViewModel(feedType: feedType, userId: userId)
    )
  }

  init(
    feedType: FeedType,
    userId: Int? = nil,
    @ViewBuilder header: () -> Header
  ) {
    self.feedType = feedType
    self.userId = userId
    self.header = header()
    _viewModel = StateObject(
      wrappedValue: ViewModel(feedType: feedType, userId: userId)
    )
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        header

        if !viewModel.error.isEmpty && viewModel.posts.isEmpty
          && !viewModel.isLoading
        {
          errorMessage
        } else if viewModel.posts.isEmpty && !viewModel.isLoading {
          emptyMessage
        } else {
          if !viewModel.posts.isEmpty {
            postsList
          }
          if viewModel.isLoading {
            loadingPlaceholder
          }
        }
      }
      .onAppear {
        if viewModel.posts.isEmpty && !viewModel.isLoading {
          viewModel.refreshPosts()
        }
      }
      .onReceive(feedRefreshManager.$refreshTrigger) { _ in
        viewModel.refreshPosts()
      }
      .refreshable {
        viewModel.refreshPosts()
      }
      .navigationTitle(feedType == .home ? "Splajompy" : "All")
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .profile(let id, let username):
          ProfileView(userId: Int(id)!, username: username)
        }
      }
      .onOpenURL { url in
        print("on open url: \(url)")
        if let route = parseDeepLink(url) {
          path.append(route)
        }
      }
    }
  }

  private func parseDeepLink(_ url: URL) -> Route? {
    guard url.scheme == "splajompy" else { return nil }

    switch url.host {
    case "user":
      guard
        let components = URLComponents(
          url: url,
          resolvingAgainstBaseURL: false
        ),
        let idParam = components.queryItems?.first(where: { $0.name == "id" })?
          .value,
        let usernameParam = components.queryItems?.first(where: {
          $0.name == "username"
        })?.value
      else {
        return nil
      }
      return .profile(id: idParam, username: usernameParam)

    default:
      return nil
    }
  }

  private var loadingPlaceholder: some View {
    VStack {
      ProgressView()
        .scaleEffect(1.5)
        .padding()
        .frame(maxWidth: .infinity)
      Spacer()
    }
  }

  private var errorMessage: some View {
    VStack {
      Spacer()
      Image(systemName: "arrow.clockwise")
        .imageScale(.large)
        .onTapGesture {
          viewModel.refreshPosts()
        }
        .padding()
      Text("There was an error.")
        .font(.title2).fontWeight(.bold)
      Text(viewModel.error)
        .foregroundColor(.red)
      Spacer()
    }
  }

  private var emptyMessage: some View {
    Text("No posts yet")
      .foregroundColor(.gray)
      .padding()
      .frame(maxWidth: .infinity, minHeight: 100)
  }

  private var postsList: some View {
    LazyVStack(spacing: 0) {
      ForEach(viewModel.posts) { post in
        PostView(
          post: post,
          showAuthor: feedType != .profile,
          onLikeButtonTapped: { viewModel.toggleLike(on: post) }
        )
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .id("post-\(feedType)_\(post.post.postId)")
        .onAppear {
          if post == viewModel.posts.last && !viewModel.isLoading
            && viewModel.hasMorePosts
          {
            viewModel.loadMorePosts()
          }
        }
        .geometryGroup()
      }
    }
  }
}
