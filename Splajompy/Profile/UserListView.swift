import SwiftUI

struct UserListView: View {
  @StateObject private var viewModel: UserListViewModel

  init(userId: Int, userListVariant: UserListVariantEnum) {
    _viewModel = StateObject(
      wrappedValue: UserListViewModel(
        userId: userId,
        userListVariant: userListVariant
      )
    )
  }

  init(viewModel: UserListViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle:
        ProgressView()
          .scaleEffect(1.5)
          .onAppear {
            Task {
              await viewModel.loadUsers(reset: true)
            }
          }
      case .loading:
        ProgressView()
          .scaleEffect(1.5)
      case .loaded(let users):
        if users.isEmpty {
          noUsersView
        } else {
          userList(
            users: users
          )
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.loadUsers(reset: true) }
        )
      }
    }
    .navigationTitle("Following")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      Text("Failed to load connections")
        .foregroundColor(.secondary)
      Button("Retry") {
        Task {
          await viewModel.loadUsers(reset: true)
        }
      }
      .buttonStyle(.bordered)
      .padding()
      Spacer()
    }
  }

  private var noUsersView: some View {
    VStack {
      Spacer()
      Text("No users found")
        .foregroundColor(.secondary)
      Spacer()
    }
  }

  private func userList(
    users: [DetailedUser],
  )
    -> some View
  {
    List {
      ForEach(users) { user in
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
              await viewModel.loadUsers()
            }
          }
        }
      }

      if viewModel.hasMoreToFetch {
        HStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.1)
            .padding()
          Spacer()
        }
      }
    }
    .listStyle(.plain)
    .refreshable {
      Task {
        await viewModel.loadUsers(reset: true)
      }
    }
  }
}

struct UserRowView: View {
  let user: DetailedUser
  let onFollowToggle: (DetailedUser) -> Void
  @State private var isLoading = false

  init(
    user: DetailedUser,
    onFollowToggle: @escaping (DetailedUser) -> Void,
  ) {
    self.user = user
    self.onFollowToggle = onFollowToggle
  }

  var body: some View {
    HStack {
      HStack {
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

      followButton
        .frame(maxWidth: .infinity, alignment: .trailing)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)

    }
    .background(
      NavigationLink(
        value: Route.profile(id: String(user.userId), username: user.username)
      ) {
        Color.clear
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    )
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
    .frame(width: 70)
    .padding(.vertical, 6)
    .background(
      user.isFollowing ? Color.gray.opacity(0.2).gradient : Color.blue.gradient
    )
    .foregroundColor(user.isFollowing ? .blue : .white)
    .animation(.spring(duration: 0.15, bounce: 0.3), value: user.isFollowing)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .disabled(isLoading)
  }
}

#Preview {
  let viewModel = UserListViewModel(
    userId: 1,
    userListVariant: .following,
    profileService: MockProfileService()
  )

  NavigationStack {
    UserListView(viewModel: viewModel)
  }
}
