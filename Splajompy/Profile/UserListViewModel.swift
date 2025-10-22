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
}

@MainActor
class UserListViewModel: ObservableObject {
  let userId: Int
  let userListVariant: UserListVariantEnum

  @Published var state: UserListState = .idle
  @Published var isFetchingMore: Bool = false
  @Published var hasMoreToFetch: Bool = false

  private let profileService: ProfileServiceProtocol
  private let fetchLimit = 20
  private var offset: Int = 0

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
    guard !isFetchingMore else { return }

    isFetchingMore = true
    defer {
      isFetchingMore = false
    }

    if reset {
      offset = 0
    }

    let result: AsyncResult<[DetailedUser]>
    switch userListVariant {
    case .following:
      result = await profileService.getFollowing(
        userId: userId,
        offset: offset,
        limit: fetchLimit
      )
    case .mutuals:
      result = await profileService.getMutuals(
        userId: userId,
        offset: offset,
        limit: fetchLimit
      )
    }

    switch result {
    case .success(let users):
      if !reset, case .loaded(let existingUsers) = state {
        state = .loaded(existingUsers + users)
      } else {
        state = .loaded(users)
      }
      offset += users.count
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
