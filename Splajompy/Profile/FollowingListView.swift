import SwiftUI

struct FollowingListView: View {
  @StateObject private var viewModel: FollowingListViewModel
  @ObservedObject var postManager: PostManager

  init(userId: Int, postManager: PostManager) {
    _viewModel = StateObject(
      wrappedValue: FollowingListViewModel(
        userId: userId
      )
    )
    self.postManager = postManager
  }

  var body: some View {
    VStack(spacing: 0) {
      switch viewModel.state {
      case .idle:
        loadingView
      case .loading:
        loadingView
      case .loaded(let users):
        userListView(users: users, isLoading: viewModel.isFetchingMore, postManager: postManager)
      case .failed(let error):
        errorView(error: error)
      }
    }
    .onAppear {
      Task {
        await viewModel.loadFollowing(reset: true)
      }
    }
    .navigationTitle("Following")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
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
          await viewModel.loadFollowing(reset: true)
        }
      }
      .buttonStyle(.bordered)
      .padding()
      Spacer()
    }
  }

  private func userListView(users: [DetailedUser], isLoading: Bool, postManager: PostManager)
    -> some View
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
                },
                postManager: postManager
              )
              .onAppear {
                if user.userId == users.last?.userId {
                  Task {
                    await viewModel.loadFollowing()
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
            await viewModel.loadFollowing(reset: true)
          }
        }
      }
    }
  }
}

struct UserRowView: View {
  let user: DetailedUser
  let onFollowToggle: (DetailedUser) -> Void
  @ObservedObject var postManager: PostManager
  @State private var isLoading = false

  init(
    user: DetailedUser, onFollowToggle: @escaping (DetailedUser) -> Void, postManager: PostManager
  ) {
    self.user = user
    self.onFollowToggle = onFollowToggle
    self.postManager = postManager
  }

  var body: some View {
    HStack(spacing: 8) {
      NavigationLink(value: Route.profile(id: String(user.userId), username: user.username)) {
        userInfoView

        Spacer()
      }
      .buttonStyle(.plain)

      followButton
    }
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
    },
    postManager: PostManager()
  )
}
