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
  case CloseFriends

  var title: String {
    switch self {
    case .following:
      "Following"
    case .mutuals:
      "Mutuals"
    case .CloseFriends:
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
    case .CloseFriends:
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
    let result = await profileService.toggleFollowing(
      userId: user.userId,
      isFollowing: user.isFollowing
    )

    switch result {
    case .success:
      if case .loaded(var users) = state {
        if let index = users.firstIndex(where: { $0.userId == user.userId }) {
          users[index].isFollowing.toggle()
          state = .loaded(users)
        }
      }
      break
    case .error(let error):
      print("Failed to toggle follow: \(error)")
    }
  }
}
