import SwiftUI

enum UserListState {
  case idle
  case loading
  case loaded([DetailedUser])
  case failed(Error)
}

enum UserListVariantEnum {
  case following
  case mutuals
  case friends

  var title: String {
    switch self {
    case .following:
      "Following"
    case .mutuals:
      "Mutuals"
    case .friends:
      "Friends"
    }
  }
}

@MainActor @Observable
class UserListViewModel {
  let userId: Int
  let userListVariant: UserListVariantEnum

  var state: UserListState = .idle
  var hasMoreToFetch: Bool = false
  var errorMessage: String? = nil

  private let profileService: ProfileServiceProtocol
  private let fetchLimit = 20
  private var isFetching: Bool = false
  private var beforeCursor: Date? = nil

  init(
    userId: Int,
    userListVariant: UserListVariantEnum,
    profileService: ProfileServiceProtocol = ProfileService()
  ) {
    self.userId = userId
    self.userListVariant = userListVariant
    self.profileService = profileService
  }

  func loadUsers(reset: Bool = false) async {
    if case .loading = state { return }
    guard isFetching == false else {
      return
    }

    isFetching = true
    defer {
      isFetching = false
    }

    if reset {
      beforeCursor = nil
    }

    let result: AsyncResult<[DetailedUser]>
    switch userListVariant {
    case .following:
      result = await profileService.getFollowing(
        userId: userId,
        limit: fetchLimit,
        before: beforeCursor
      )
    case .mutuals:
      result = await profileService.getMutuals(
        userId: userId,
        limit: fetchLimit,
        before: beforeCursor
      )
    case .friends:
      result = await profileService.getFriends(
        userId: userId,
        limit: fetchLimit,
        before: beforeCursor
      )
    }

    switch result {
    case .success(let users):
      if !reset, case .loaded(let existingUsers) = state {
        state = .loaded(existingUsers + users)
      } else {
        state = .loaded(users)
      }
      beforeCursor = users.last?.createdAt
      hasMoreToFetch = users.count == fetchLimit
    case .error(let error):
      if case .idle = state {
        state = .failed(error)
      }
      print("Failed to load users: \(error)")
    }
  }

  func toggleFollow(for user: DetailedUser) async {
    if case .loaded(var users) = state {
      if let index = users.firstIndex(where: { $0.userId == user.userId }) {
        users[index].isFollowing.toggle()
        state = .loaded(users)
      }
    }

    let result = await profileService.toggleFollowing(
      userId: user.userId,
      isFollowing: user.isFollowing
    )

    if case .error(let error) = result {
      // Rollback
      if case .loaded(var users) = state {
        if let index = users.firstIndex(where: { $0.userId == user.userId }) {
          users[index].isFollowing.toggle()
          state = .loaded(users)
        }
      }
      errorMessage = "Failed to update follow status"
      print("Failed to toggle follow: \(error)")
    }
  }

  func addFriend(publicUser: PublicUser) async {
    if case .loaded(let users) = state {
      if users.contains(where: { $0.userId == publicUser.userId }) {
        return
      }
    }

    // Create a temporary DetailedUser for optimistic update
    let tempUser = DetailedUser(
      userId: publicUser.userId,
      email: "",
      username: publicUser.username,
      createdAt: publicUser.createdAt,
      name: publicUser.name,
      bio: "",
      isFollower: false,
      isFollowing: false,
      isBlocking: false,
      isMuting: false,
      isFriend: false,
      mutuals: [],
      mutualCount: 0,
      isVerified: publicUser.isVerified,
      displayProperties: publicUser.displayProperties ?? UserDisplayProperties(fontChoiceId: 0)
    )

    switch state {
    case .loaded(var users):
      users.insert(tempUser, at: 0)
      state = .loaded(users)
    case .idle, .loading, .failed:
      state = .loaded([tempUser])
    }

    let result = await profileService.addFriend(userId: publicUser.userId)
    if case .error(let error) = result {
      if case .loaded(var users) = state {
        users.removeAll { $0.userId == publicUser.userId }
        state = .loaded(users)
      }
      errorMessage = "Failed to add friend"
      print("Failed to add friend: \(error)")
    }
  }

  func removeFriend(user: DetailedUser) async {
    var originalIndex: Int?
    if case .loaded(let users) = state {
      originalIndex = users.firstIndex(where: { $0.userId == user.userId })
    }

    if case .loaded(var users) = state {
      users.removeAll { $0.userId == user.userId }
      state = .loaded(users)
    }

    let result = await profileService.removeFriend(userId: user.userId)
    if case .error(let error) = result {
      if case .loaded(var users) = state {
        let insertIndex = min(originalIndex ?? 0, users.count)
        users.insert(user, at: insertIndex)
        state = .loaded(users)
      }
      errorMessage = "Failed to remove friend"
      print("Failed to remove friend: \(error)")
    }
  }

  func clearError() {
    errorMessage = nil
  }
}
