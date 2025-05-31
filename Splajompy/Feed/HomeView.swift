import SwiftUI

struct HomeView: View {
  @State private var filterState = FilterState()
  @State private var path = NavigationPath()
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
        feedType: decodedState.mode == .all ? .all : .home
      )
    )
  }

  private func saveFilterState(_ state: FilterState) {
    if let encoded = try? JSONEncoder().encode(state) {
      UserDefaults.standard.set(encoded, forKey: "feedFilterState")
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      Group {
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
      .id(filterState.mode)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Image("Full_Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 30)
        }

        ToolbarItem(placement: .principal) {
          Menu {
            Button {
              withAnimation(.snappy) {
                filterState.mode = .all
                saveFilterState(filterState)
                viewModel.feedType = .all
                Task {
                  await viewModel.refreshPosts()
                }
              }
            } label: {
              HStack {
                Text("All")
                if filterState.mode == .all {
                  Image(systemName: "checkmark")
                }
              }
            }

            Button {
              withAnimation(.snappy) {
                filterState.mode = .following
                saveFilterState(filterState)
                viewModel.feedType = .home
                Task {
                  await viewModel.refreshPosts()
                }
              }
            } label: {
              HStack {
                Text("Following")
                if filterState.mode == .following {
                  Image(systemName: "checkmark")
                }
              }
            }
          } label: {
            HStack {
              Text(filterState.mode == .all ? "All" : "Following")
              Image(systemName: "chevron.down")
                .font(.caption)
            }
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                .background(Color.clear)
            )
          }
          .menuStyle(BorderlessButtonMenuStyle())
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { isShowingNewPostView = true }) {
            Image(systemName: "plus")
          }
          .buttonStyle(.plain)
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .profile(let id, let username):
          ProfileView(userId: Int(id)!, username: username)
        case .post(let id):
          StandalonePostView(postId: id)
        }
      }
      .onOpenURL { url in
        if let route = parseDeepLink(url) {
          path.append(route)
        }
      }
    }
    .sheet(isPresented: $isShowingNewPostView) {
      NewPostView(
        onPostCreated: { feedRefreshManager.triggerRefresh() }
      )
      .interactiveDismissDisabled()
    }
    .onAppear {
      // Debug: Print current state
      print("HomeView appeared - State: \(viewModel.state)")
      print("HomeView appeared - Posts count: \(viewModel.posts.count)")
    }
  }

  private func postList(posts: [DetailedPost]) -> some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(posts) { post in
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
            if post == viewModel.posts.last && viewModel.canLoadMore {
              Task {
                await viewModel.loadMorePosts()
              }
            }
          }
          .geometryGroup()
        }
      }
    }
    .refreshable {
      await viewModel.refreshPosts()
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

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      Image(systemName: "arrow.clockwise")
        .imageScale(.large)
        .onTapGesture {
          Task {
            await viewModel.refreshPosts()
          }
        }
        .padding()
      Text("There was an error.")
        .font(.title2).fontWeight(.bold)
      Text(error.localizedDescription)
        .foregroundColor(.red)
        .multilineTextAlignment(.center)
        .padding()
      Button("Retry") {
        Task {
          await viewModel.refreshPosts()
        }
      }
      .buttonStyle(.borderedProminent)
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
