import SwiftUI

/// A flexible view to display a list of users.
struct UserListView: View {
  private var userListVariant: UserListVariantEnum
  @State private var viewModel: UserListViewModel
  @State private var isPresentingUserSearch: Bool = false

  init(userId: Int, userListVariant: UserListVariantEnum) {
    _viewModel = State(
      wrappedValue: UserListViewModel(
        userId: userId,
        userListVariant: userListVariant
      )
    )
    self.userListVariant = userListVariant
  }

  init(viewModel: UserListViewModel, userListVariant: UserListVariantEnum) {
    _viewModel = State(wrappedValue: viewModel)
    self.userListVariant = userListVariant
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
    #if os(macOS)
      .frame(maxWidth: 600)
      .frame(maxWidth: .infinity)
    #endif
    .navigationTitle(userListVariant.title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      if userListVariant == .friends {
        #if os(iOS)
          ToolbarItem(placement: .topBarTrailing) {
            Button("Add Friend", systemImage: "plus") {
              isPresentingUserSearch = true
            }
            .buttonStyle(.borderedProminent)
          }
        #else
          ToolbarItem(placement: .primaryAction) {
            Button("Add Friend", systemImage: "plus") {
              isPresentingUserSearch = true
            }
            .buttonStyle(.borderedProminent)
          }
        #endif
      }
    }
    .sheet(isPresented: $isPresentingUserSearch) {
      NavigationStack {
        SearchView(onUserSelected: { selectedUser in
          // don't allow adding self
          guard selectedUser.userId != viewModel.userId else { return }
          isPresentingUserSearch = false
          Task {
            await viewModel.addFriend(publicUser: selectedUser)
          }
        })
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            if #available(iOS 26, macOS 26, *) {
              Button(role: .close) {
                isPresentingUserSearch = false
              }
            } else {
              Button("Cancel") {
                isPresentingUserSearch = false
              }
            }
          }
        }
      }
    }
    .alert(
      "Error",
      isPresented: .init(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.clearError() } }
      )
    ) {
      Button("OK") {
        viewModel.clearError()
      }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  private var noUsersView: some View {
    Text("There's nobody here")
      .fontWeight(.bold)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private func userList(
    users: [DetailedUser]
  )
    -> some View
  {
    ScrollView {
      LazyVStack {
        ForEach(users) { user in
          UserRowView(
            user: user,
            variant: userListVariant,
            onFollowToggle: { user in
              await viewModel.toggleFollow(for: user)
            },
            onRemove: { user in
              await viewModel.removeFriend(user: user)
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
  let variant: UserListVariantEnum
  let onFollowToggle: (DetailedUser) async -> Void
  let onRemove: (DetailedUser) async -> Void
  @State private var isLoading = false

  init(
    user: DetailedUser,
    variant: UserListVariantEnum,
    onFollowToggle: @escaping (DetailedUser) async -> Void,
    onRemove: @escaping (DetailedUser) async -> Void
  ) {
    self.user = user
    self.variant = variant
    self.onFollowToggle = onFollowToggle
    self.onRemove = onRemove
  }

  var body: some View {
    HStack(spacing: 8) {
      ProfileDisplayNameView(user: user, alignVertically: false)
      Spacer()
      if variant == .friends {
        removeButton
      } else {
        followButton
      }
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

  private var removeButton: some View {
    Button(action: {
      guard !isLoading else { return }
      Task {
        isLoading = true
        await onRemove(user)
        isLoading = false
      }
    }) {
      if isLoading {
        ProgressView()
          .scaleEffect(0.8)
      } else {
        Text("Remove")
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .frame(width: 70)
    .padding(.vertical, 6)
    .background(Color.red.opacity(0.15).gradient)
    .foregroundColor(.red)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .buttonStyle(.plain)
    .disabled(isLoading)
  }

  private var followButton: some View {
    Button(action: {
      guard !isLoading else { return }
      Task {
        isLoading = true
        await onFollowToggle(user)
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
    .buttonStyle(.plain)
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
    UserListView(viewModel: viewModel, userListVariant: .friends)
  }
}
