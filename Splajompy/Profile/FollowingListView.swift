import SwiftUI

struct FollowingListView: View {
  @StateObject private var viewModel: FollowersFollowingViewModel

  init(userId: Int) {
    _viewModel = StateObject(
      wrappedValue: FollowersFollowingViewModel(
        userId: userId
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      switch viewModel.state {
      case .idle:
        loadingView
          .onAppear {
            Task {
              await viewModel.loadData()
            }
          }
      case .loading:
        loadingView
      case .loaded:
        loadedContent
      case .failed(let error):
        errorView(error: error)
      }
    }
    .onAppear {
      if case .loaded = viewModel.state {
        Task {
          await viewModel.loadData()
        }
      }
    }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  @ViewBuilder
  private var loadedContent: some View {
    userListView(
      users: viewModel.following,
      isLoading: viewModel.isLoadingFollowing
    )
  }

  private var loadingView: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
      Spacer()
    }
  }

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      Text("Failed to load connections")
        .foregroundColor(.secondary)
      Button("Retry") {
        Task {
          await viewModel.loadData()
        }
      }
      .buttonStyle(.bordered)
      .padding()
      Spacer()
    }
  }

  private func userListView(users: [DetailedUser], isLoading: Bool) -> some View
  {
    Group {
      if isLoading && users.isEmpty {
        VStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.5)
          Spacer()
        }
      } else if users.isEmpty {
        VStack {
          Spacer()
          Text("No users found")
            .foregroundColor(.secondary)
          Spacer()
        }
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(users, id: \.userId) { user in
              UserRowView(
                user: user,
                onFollowToggle: { user in
                  Task {
                    await viewModel.toggleFollow(for: user)
                  }
                }
              )
              .onAppear {
                if user.userId == users.last?.userId {
                  Task {
                    if viewModel.selectedTab == .followers {
                      await viewModel.loadMoreFollowers()
                    } else {
                      await viewModel.loadMoreFollowing()
                    }
                  }
                }
              }
            }

            if isLoading {
              HStack {
                Spacer()
                ProgressView()
                  .scaleEffect(1.1)
                  .padding()
                Spacer()
              }
            }
          }
        }
        .refreshable {
          Task {
            await viewModel.refreshCurrentTab()
          }
        }
      }
    }
  }
}

struct UserRowView: View {
  let user: DetailedUser
  let onFollowToggle: (DetailedUser) -> Void
  @State private var isLoading = false

  init(user: DetailedUser, onFollowToggle: @escaping (DetailedUser) -> Void) {
    self.user = user
    self.onFollowToggle = onFollowToggle
  }

  var body: some View {
    HStack(spacing: 8) {
      userInfoView

      Spacer()

      followButton
    }
    .background(
      NavigationLink(
        destination: ProfileView(
          userId: user.userId,
          username: user.username,
          postManager: PostManager()
        )
      ) {
        Color.clear
      }
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var userInfoView: some View {
    HStack(spacing: 6) {
      if let name = user.name, !name.isEmpty {
        Text(name)
          .font(.headline)
          .lineLimit(1)
      }
      Text("@\(user.username)")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
  }

  private var followButton: some View {
    Button(action: {
      guard !isLoading else { return }
      Task {
        isLoading = true
        onFollowToggle(user)
        isLoading = false
      }
    }) {
      if isLoading {
        ProgressView()
          .scaleEffect(0.8)
      } else {
        Text(user.isFollowing ? "Unfollow" : "Follow")
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .font(.caption)
    .fontWeight(.medium)
    .frame(width: 70)
    .padding(.vertical, 6)
    .background(user.isFollowing ? Color.clear : .blue)
    .foregroundColor(user.isFollowing ? .blue : .white)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(user.isFollowing ? Color.blue : Color.clear, lineWidth: 1)
    )
    .animation(.spring(duration: 0.15, bounce: 0.3), value: user.isFollowing)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .disabled(isLoading)
    .buttonStyle(.plain)
  }
}

#Preview {
  @Previewable @State var user = DetailedUser(
    userId: 1,
    email: "john@example.com",
    username: "johndoe",
    createdAt: Date(),
    name: "John Doe",
    bio: "iOS Developer",
    isFollower: true,
    isFollowing: false,
    isBlocking: false,
    mutuals: ["alice", "bob"]
  )

  return UserRowView(
    user: user,
    onFollowToggle: { _ in
      user.isFollowing.toggle()
    }
  )
}
