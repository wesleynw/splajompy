import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int
  let isOwnProfile: Bool
  @State private var isShowingProfileEditor: Bool = false
  @StateObject private var viewModel: ViewModel
  @StateObject private var feedViewModel: FeedViewModel
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
    _feedViewModel = StateObject(
      wrappedValue: FeedViewModel(feedType: .profile, userId: userId)
    )
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
    _feedViewModel = StateObject(
      wrappedValue: FeedViewModel(feedType: .profile, userId: userId)
    )
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if viewModel.isLoadingProfile {
          ProgressView()
            .scaleEffect(1.5)
            .padding()
        } else if let user = viewModel.profile {
          profileHeader(user: user)
          postsList
        } else if !viewModel.isLoadingProfile {
          Text("This user doesn't exist.")
            .font(.title3)
            .fontWeight(.bold)
            .padding(.top, 40)
        }
      }
    }
    .refreshable {
      feedRefreshManager.triggerRefresh()
      viewModel.loadProfile()
      await feedViewModel.refreshPosts()
    }
    .sheet(isPresented: $isShowingProfileEditor) {
      ProfileEditorView(viewModel: viewModel)
        .interactiveDismissDisabled()
    }
    .navigationTitle("@" + self.username)
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
      if let isFollowing = viewModel.profile?.isFollowing, !isOwnProfile,
        !isCurrentProfile
      {
        if isFollowing {
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

  private var postsList: some View {
    Group {
      switch feedViewModel.state {
      case .idle:
        loadingPlaceholder
      case .loading:
        if feedViewModel.posts.isEmpty {
          loadingPlaceholder
        } else {
          postsContent(posts: feedViewModel.posts)
        }
      case .loaded(let posts):
        if posts.isEmpty {
          emptyMessage
        } else {
          postsContent(posts: posts)
        }
      case .failed(let error):
        errorView(error: error)
      }
    }
  }

  private func postsContent(posts: [DetailedPost]) -> some View {
    LazyVStack(spacing: 0) {
      ForEach(posts) { post in
        PostView(
          post: post,
          showAuthor: false,
          onLikeButtonTapped: { feedViewModel.toggleLike(on: post) },
          onPostDeleted: { feedViewModel.deletePost(on: post) }
        )
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .id("post-profile_\(post.post.postId)")
        .onAppear {
          if post == posts.last && feedViewModel.canLoadMore {
            Task {
              await feedViewModel.loadMorePosts()
            }
          }
        }
        .geometryGroup()
      }
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
            await feedViewModel.refreshPosts()
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

#Preview {
  let mockViewModel = ProfileView.ViewModel(
    userId: 1,
    profileService: MockProfileService()
  )
  let feedRefreshManager = FeedRefreshManager()
  let authManager = AuthManager()
  ProfileView(userId: 1, username: "wesley", viewModel: mockViewModel)
    .environmentObject(feedRefreshManager)
    .environmentObject(authManager)
}
