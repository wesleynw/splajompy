import SwiftUI

enum FollowersFollowingState {
  case idle
  case loading
  case loaded
  case failed(Error)
}

enum FollowersFollowingTab {
  case followers
  case following
}

@MainActor class FollowersFollowingViewModel: ObservableObject {
  let userId: Int
  @Published var selectedTab: FollowersFollowingTab = .followers
  @Published var state: FollowersFollowingState = .idle
  @Published var followers: [DetailedUser] = []
  @Published var following: [DetailedUser] = []
  @Published var isLoadingFollowers = false
  @Published var isLoadingFollowing = false
  @Published var hasMoreFollowers = true
  @Published var hasMoreFollowing = true

  private let profileService: ProfileServiceProtocol
  private let pageSize = 20
  private var totalFollowersLoaded = 0
  private var totalFollowingLoaded = 0

  init(
    userId: Int, initialTab: FollowersFollowingTab = .followers,
    profileService: ProfileServiceProtocol = ProfileService()
  ) {
    self.userId = userId
    self.selectedTab = initialTab
    self.profileService = profileService
  }

  func loadData() async {
    state = .loading

    async let followersResult: () = loadFollowers()
    async let followingResult: () = loadFollowing()

    await followersResult
    await followingResult

    state = .loaded
  }

  func loadFollowers() async {
    isLoadingFollowers = true
    let result = await profileService.getFollowers(userId: userId, offset: 0, limit: pageSize)

    switch result {
    case .success(let users):
      followers = users
      totalFollowersLoaded = users.count
      hasMoreFollowers = users.count == pageSize
    case .error(let error):
      if case .idle = state {
        state = .failed(error)
      }
      print("Failed to load followers: \(error)")
    }
    isLoadingFollowers = false
  }

  func loadFollowing() async {
    isLoadingFollowing = true
    let result = await profileService.getFollowing(userId: userId, offset: 0, limit: pageSize)

    switch result {
    case .success(let users):
      following = users
      totalFollowingLoaded = users.count
      hasMoreFollowing = users.count == pageSize
    case .error(let error):
      if case .idle = state {
        state = .failed(error)
      }
      print("Failed to load following: \(error)")
    }
    isLoadingFollowing = false
  }

  func loadMoreFollowers() async {
    guard hasMoreFollowers && !isLoadingFollowers else { return }

    isLoadingFollowers = true
    let result = await profileService.getFollowers(
      userId: userId, offset: totalFollowersLoaded, limit: pageSize)

    switch result {
    case .success(let users):
      followers.append(contentsOf: users)
      totalFollowersLoaded += users.count
      hasMoreFollowers = users.count == pageSize
    case .error(let error):
      print("Failed to load more followers: \(error)")
    }
    isLoadingFollowers = false
  }

  func loadMoreFollowing() async {
    guard hasMoreFollowing && !isLoadingFollowing else { return }

    isLoadingFollowing = true
    let result = await profileService.getFollowing(
      userId: userId, offset: totalFollowingLoaded, limit: pageSize)

    switch result {
    case .success(let users):
      following.append(contentsOf: users)
      totalFollowingLoaded += users.count
      hasMoreFollowing = users.count == pageSize
    case .error(let error):
      print("Failed to load more following: \(error)")
    }
    isLoadingFollowing = false
  }

  func refreshCurrentTab() async {
    switch selectedTab {
    case .followers:
      totalFollowersLoaded = 0
      hasMoreFollowers = true
      await loadFollowers()
    case .following:
      totalFollowingLoaded = 0
      hasMoreFollowing = true
      await loadFollowing()
    }
  }

  func toggleFollow(for user: DetailedUser) async {
    let isCurrentlyFollowing = user.isFollowing
    let newFollowingState = !isCurrentlyFollowing

    updateUserFollowState(userId: user.userId, isFollowing: newFollowingState)

    let result = await profileService.toggleFollowing(
      userId: user.userId,
      isFollowing: isCurrentlyFollowing
    )

    switch result {
    case .success:
      break
    case .error(let error):
      updateUserFollowState(userId: user.userId, isFollowing: isCurrentlyFollowing)
      print("Failed to toggle follow: \(error)")
    }
  }

  private func updateUserFollowState(userId: Int, isFollowing: Bool) {
    if let index = followers.firstIndex(where: { $0.userId == userId }) {
      let user = followers[index]
      followers[index].isFollowing = isFollowing

      if isFollowing {
        var updatedUser = user
        updatedUser.isFollowing = true
        following.insert(updatedUser, at: 0)
        totalFollowingLoaded += 1
      }
    }

    if let index = following.firstIndex(where: { $0.userId == userId }) {
      if !isFollowing {
        following.remove(at: index)
        totalFollowingLoaded -= 1
      } else {
        following[index].isFollowing = isFollowing
      }
    }
  }
}
