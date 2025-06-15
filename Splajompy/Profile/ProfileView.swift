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
    guard let currentUser = authManager.getCurrentUser() else { return false }
    return currentUser.userId == userId
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
    mainContent
      .sheet(isPresented: $isShowingProfileEditor) {
        ProfileEditorView(viewModel: viewModel)
          .interactiveDismissDisabled()
      }
      .navigationTitle("@" + self.username)
      .toolbar {
        if !isOwnProfile && !isCurrentProfile {
          Menu {
            if case .loaded(let user, _) = viewModel.state {
              if user.isBlocking {
                Button(role: .destructive, action: viewModel.toggleBlocking) {
                  Label(
                    "Unblock @\(user.username)",
                    systemImage: "person.fill.checkmark"
                  )
                }
              } else {
                Button(role: .destructive, action: viewModel.toggleBlocking) {
                  Label(
                    "Block @\(user.username)",
                    systemImage: "person.fill.xmark"
                  )
                }
              }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .disabled(viewModel.isLoadingBlockButton)
        }
      }
      .onAppear {
        Task {
          await viewModel.loadProfile()
        }
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      loadingPlaceholder
    case .loaded(let user, let posts):
      ScrollView {
        profileList(user: user, posts: posts)
      }
      .refreshable {
        await viewModel.loadProfile()
      }
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
          PostView(
            post: post,
            showAuthor: false,
            onLikeButtonTapped: { viewModel.toggleLike(on: post) },
            onPostDeleted: { viewModel.deletePost(on: post) }
          )
          .environmentObject(feedRefreshManager)
          .environmentObject(authManager)
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
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: posts.count)
  }

  private func profileHeader(user: UserProfile) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          if !user.name.isEmpty {
            Text(user.name)
              .font(.title2)
              .fontWeight(.bold)
              .lineLimit(1)
          }
        }

        Spacer()

      }

      if !user.bio.isEmpty {
        Text(user.bio)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !isOwnProfile && !isCurrentProfile {
        RelationshipIndicator(user: user)
      }

      if !isOwnProfile && !isCurrentProfile {
        if !user.isBlocking {
          if user.isFollowing {
            Button(action: viewModel.toggleFollowing) {
              if viewModel.isLoadingFollowButton {
                ProgressView()
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
              } else {
                Text("Follow")
                  .frame(maxWidth: .infinity)
              }
            }
            .buttonStyle(.borderedProminent)
          }
        } else {
          Button(action: viewModel.toggleBlocking) {
            Text("Unblock")
              .frame(maxWidth: .infinity)
              .foregroundStyle(.red.opacity(0.7))
          }
          .buttonStyle(.bordered)
        }
      } else if isOwnProfile {
        Button(action: { isShowingProfileEditor = true }) {
          Text("Edit Profile")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }

  private var loadingPlaceholder: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
        .padding()
      Spacer()
    }
  }

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      VStack {
        Text("There was an error :/")
          .font(.title2)
          .fontWeight(.bold)
        Text(error.localizedDescription)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
      Button {
        Task {
          await viewModel.loadPosts(reset: true)
        }
      } label: {
        HStack {
          Image(systemName: "arrow.clockwise")
          Text("Retry")
        }
      }
      .padding()
      .buttonStyle(.bordered)
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
