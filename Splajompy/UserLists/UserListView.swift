import PostHog
import SwiftUI

/// A flexible view to display a list of users.
struct UserListView: View {
  private var userListVariant: UserListVariantEnum
  private var postId: Int?
  @State private var viewModel: UserListViewModel
  @State private var isPresentingUserSearch: Bool = false

  init(
    identifier: Int,
    userListVariant: UserListVariantEnum,
    postId: Int? = nil
  ) {
    _viewModel = State(
      wrappedValue: UserListViewModel(
        identifier: identifier,
        userListVariant: userListVariant
      )
    )
    self.userListVariant = userListVariant
    self.postId = postId
  }

  init(viewModel: UserListViewModel, userListVariant: UserListVariantEnum, postId: Int? = nil) {
    _viewModel = State(wrappedValue: viewModel)
    self.userListVariant = userListVariant
    self.postId = postId
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          .task {
            if case .idle = viewModel.state {
              await viewModel.loadUsers(reset: true)
            }
          }
          #if os(macOS)
            .controlSize(.small)
          #endif
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
          source: "UserListView",
          onRetry: { await viewModel.loadUsers(reset: true) }
        )
      }
    }
    .navigationTitle(userListVariant.title)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    .overlay(alignment: .bottom) {
      if let postId {
        NavigationLink(value: Route.post(id: postId)) {
          Label("Go to post", systemImage: "arrow.up.right.square")
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glass)
          } else {
            $0.buttonStyle(.bordered)
          }
        }
      }
    }
    .sheet(isPresented: $isPresentingUserSearch) {
      NavigationStack {
        SearchView(onUserSelected: { selectedUser in
          // don't allow adding self
          guard selectedUser.userId != viewModel.identifier else { return }
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
    VStack {
      Image("snail-hiding")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 200, height: 200)

      Text("There's nobody here")
        .font(.title3)
        .fontWeight(.semibold)
    }
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
      #if os(macOS)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
      #endif
    }
    .refreshable {
      await Task {
        await viewModel.loadUsers(reset: true)
      }.value
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
      } else if variant != .notification {
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
    .foregroundStyle(.red)
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
    .foregroundStyle(user.isFollowing ? .blue : .white)
    .animation(.spring(duration: 0.15, bounce: 0.3), value: user.isFollowing)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .buttonStyle(.plain)
    .disabled(isLoading)
  }
}

#Preview {
  let viewModel = UserListViewModel(
    identifier: 1,
    userListVariant: .following,
    profileService: MockProfileService()
  )

  NavigationStack {
    UserListView(viewModel: viewModel, userListVariant: .notification, postId: 5)
  }
}
