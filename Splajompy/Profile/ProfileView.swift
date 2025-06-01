import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int
  let isOwnProfile: Bool
  @State private var isShowingProfileEditor: Bool = false
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  private var isCurrentProfile: Bool {
    authManager.getCurrentUser().userId == userId
  }

  init(userId: Int, username: String, isOwnProfile: Bool = false) {
    self.userId = userId
    self.username = username
    self.isOwnProfile = isOwnProfile
    _viewModel = StateObject(wrappedValue: ViewModel(userId: userId))
  }

  init(
    userId: Int,
    username: String,
    isOwnProfile: Bool = false,
    viewModel: ViewModel
  ) {
    self.userId = userId
    self.username = username
    self.isOwnProfile = isOwnProfile
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ScrollView {
      mainContent
    }
    .refreshable {
      await viewModel.loadProfile()
    }
    .sheet(isPresented: $isShowingProfileEditor) {
      ProfileEditorView(viewModel: viewModel)
        .interactiveDismissDisabled()
    }
    .navigationTitle("@" + self.username)
    .task {
      await viewModel.loadProfile()
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      loadingPlaceholder
    case .loaded(let user, let posts):
      profileList(user: user, posts: posts)
    case .failed(let error):
      errorView(error: error)
    }
  }

  private func profileList(user: UserProfile, posts: [DetailedPost])
    -> some View
  {
    LazyVStack(spacing: 0) {
      profileHeader(user: user)

      if posts.isEmpty {
        emptyMessage
      } else {
        ForEach(posts) { post in
          VStack {
            PostView(
              post: post,
              showAuthor: false,
              onLikeButtonTapped: { viewModel.toggleLike(on: post) },
              onPostDeleted: { viewModel.deletePost(on: post) }
            )
          }
          .environmentObject(feedRefreshManager)
          .environmentObject(authManager)
          .id("post-profile_\(post.post.postId)")
          .transition(.opacity)
          .onAppear {
            if post == posts.last && viewModel.canLoadMorePosts {
              Task {
                await viewModel.loadPosts()
              }
            }
          }
        }

        if viewModel.isLoadingMorePosts {
          HStack {
            Spacer()
            ProgressView()
              .padding()
            Spacer()
          }
          .transition(.opacity)
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: posts.count)
    .animation(.easeInOut(duration: 0.2), value: viewModel.isLoadingMorePosts)
  }

  private func profileHeader(user: UserProfile) -> some View {
    VStack(alignment: .leading) {
      if !user.name.isEmpty {
        Text(user.name)
          .font(.title2)
          .fontWeight(.black)
          .lineLimit(1)
      }
      if !user.bio.isEmpty {
        Text(user.bio)
          .padding(.vertical, 10)
      }
      if !isOwnProfile && !isCurrentProfile {
        if user.isFollowing {
          Button(action: viewModel.toggleFollowing) {
            if viewModel.isLoadingFollowButton {
              ProgressView()
                .frame(maxWidth: .infinity)
            } else {
              Text("Unfollow")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.bordered)
        } else {
          Button(action: viewModel.toggleFollowing) {
            if viewModel.isLoadingFollowButton {
              ProgressView()
                .frame(maxWidth: .infinity)
            } else {
              Text("Follow")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.borderedProminent)
        }
      } else if isOwnProfile {
        Button(action: { isShowingProfileEditor = true }) {
          Text("Edit Profile")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
      if user.isFollower && !isOwnProfile {
        Text("Follows You")
          .fontWeight(.bold)
          .foregroundColor(Color.gray.opacity(0.4))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
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
            await viewModel.loadProfile()
          }
        }
        .padding()
      Text("There was an error loading posts.")
        .font(.title2).fontWeight(.bold)
      Text(error.localizedDescription)
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
