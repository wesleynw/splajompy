import SwiftUI

struct HomeView: View {
  @State private var filterState = FilterState()
  @State private var path = NavigationPath()
  @State private var isShowingNewPostView = false
  @StateObject private var viewModel: FeedView.ViewModel
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
      wrappedValue: FeedView.ViewModel(
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
        if !viewModel.error.isEmpty && viewModel.posts.isEmpty
          && !viewModel.isLoading
        {
          errorMessage
        } else if viewModel.posts.isEmpty && !viewModel.isLoading {
          emptyMessage
        } else {
          if !viewModel.posts.isEmpty {
            postList
          }
          if viewModel.isLoading {
            loadingPlaceholder
          }
        }
      }
      .id(filterState.mode)  // Force view refresh
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
  }

  private var postList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.posts) { post in
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
            if post == viewModel.posts.last && !viewModel.isLoading
              && viewModel.hasMorePosts
            {
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

  private var errorMessage: some View {
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
}
