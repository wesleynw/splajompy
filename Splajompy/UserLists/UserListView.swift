import SwiftUI

/// A flexible view to display a list of users.
struct UserListView: View {
  private var userListVariant: UserListVariantEnum
  @State private var viewModel: UserListViewModel

  init(userId: Int, userListVariant: UserListVariantEnum) {
    _viewModel = State(
      wrappedValue: UserListViewModel(
        userId: userId,
        userListVariant: userListVariant
      )
    )
    self.userListVariant = userListVariant
  }

  init(viewModel: UserListViewModel) {
    _viewModel = State(wrappedValue: viewModel)
    self.userListVariant = viewModel.userListVariant
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle:
        ProgressView()
          .onAppear {
            Task {
              await viewModel.loadUsers(reset: true)
            }
          }
      case .loading:
        ProgressView()
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
    .navigationTitle(userListVariant.title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
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
    ScrollView {
      LazyVStack {
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

          if user.userId != users.last?.userId {
            Divider()
              .padding(.leading, 16)
          }
        }

        if viewModel.hasMoreToFetch {
          HStack {
            Spacer()
            ProgressView()
              .padding()
            Spacer()
          }
        }
      }

    }
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
    onFollowToggle: @escaping (DetailedUser) -> Void
  ) {
    self.user = user
    self.onFollowToggle = onFollowToggle
  }

  var body: some View {
    HStack(spacing: 8) {
      ProfileDisplayNameView(user: user, alignVertically: false)
      Spacer()
      followButton
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
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
