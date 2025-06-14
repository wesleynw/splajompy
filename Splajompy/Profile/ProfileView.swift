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
        relationshipInfoCard(user: user)
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

  @ViewBuilder
  private func relationshipInfoCard(user: UserProfile) -> some View {
    let hasRelationship =
      user.relationshipType != "none" && !user.relationshipType.isEmpty
    let isFollower = user.isFollower

    if hasRelationship || isFollower {
      VStack(spacing: 8) {
        if hasRelationship {
          relationshipRow(user: user)
        }

        if isFollower {
          followsYouRow()
        }
      }
      .padding(12)
      .background(Color.gray.opacity(0.3).gradient)
      .cornerRadius(8)
    }
  }

  @ViewBuilder
  private func relationshipRow(user: UserProfile) -> some View {
    HStack(spacing: 0) {
      relationshipIcon(for: user.relationshipType)
        .font(.system(size: 16))
        .foregroundColor(relationshipColor(for: user.relationshipType))
        .frame(width: 24, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        Text(relationshipTitle(for: user, type: user.relationshipType))
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        if let mutuals = user.mutualUsernames, !mutuals.isEmpty,
          user.relationshipType == "mutual"
        {
          Text(formatMutualFriends(mutuals))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
      .padding(.leading, 12)

      Spacer()
    }
  }

  @ViewBuilder
  private func followsYouRow() -> some View {
    HStack(spacing: 0) {
      Image(systemName: "person.fill.badge.plus")
        .font(.system(size: 16))
        .foregroundColor(.blue)
        .frame(width: 24, alignment: .center)

      Text("Follows you")
        .font(.subheadline)
        .fontWeight(.medium)
        .padding(.leading, 12)

      Spacer()
    }
  }

  private func relationshipIcon(for type: String) -> Image {
    switch type {
    case "friend":
      return Image(systemName: "person.fill.checkmark")
    case "mutual":
      return Image(systemName: "person.3.fill")
    default:
      return Image(systemName: "person.fill")
    }
  }

  private func relationshipColor(for type: String) -> Color {
    switch type {
    case "friend":
      return .green
    case "mutual":
      return .purple
    default:
      return .blue
    }
  }

  private func relationshipTitle(for user: UserProfile, type: String) -> String {
    switch type {
    case "friend":
      return "Friend"
    case "mutual":
      if let mutuals = user.mutualUsernames, !mutuals.isEmpty {
        return mutuals.count == 1
          ? "1 mutual" : "\(mutuals.count) mutuals"
      } else {
        return "Mutual"
      }
    default:
      return "Mutual"
    }
  }

  private func formatMutualFriends(_ mutuals: [String]) -> String {
    if mutuals.count == 1 {
      return "@\(mutuals[0])"
    } else if mutuals.count == 2 {
      return "@\(mutuals[0]) and @\(mutuals[1])"
    } else if mutuals.count == 3 {
      return "@\(mutuals[0]), @\(mutuals[1]) and @\(mutuals[2])"
    } else {
      return "@\(mutuals[0]), @\(mutuals[1]) and \(mutuals.count - 2) others"
    }
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
