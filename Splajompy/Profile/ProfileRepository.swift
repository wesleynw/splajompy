import Foundation

struct UserProfile: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: String
  let name: String
  let bio: String
  let isFollower: Bool
  var isFollowing: Bool
}

protocol ProfileServiceProtocol: Sendable {
  func getProfile(userId: Int) async -> AsyncResult<UserProfile>

  func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<
    EmptyResponse
  >
}

struct ProfileService: ProfileServiceProtocol {
  func getProfile(userId: Int) async -> AsyncResult<UserProfile> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isFollowing ? "DELETE" : "POST"

    return await APIService.performRequest(
      endpoint: "follow/\(userId)",
      method: method
    )
  }
}

final class MockUserStore: @unchecked Sendable { // unchecked ok here because it's just a mock
  var users: [Int: UserProfile] = [
    1: UserProfile(
      userId: 1,
      email: "wesleynw@pm.me",
      username: "wesleynw",
      createdAt: "2023-05-15T10:30:00Z",
      name: "Wesley 🔥",
      bio: "splajompy creator",
      isFollower: false,
      isFollowing: false
    ),
    2: UserProfile(
      userId: 2,
      email: "jane@example.com",
      username: "janesmith",
      createdAt: "2023-06-20T14:45:00Z",
      name: "Jane Smith",
      bio: "test user",
      isFollower: true,
      isFollowing: false
    ),
  ]
}

struct MockProfileService: ProfileServiceProtocol {
  private let store = MockUserStore()

  func getProfile(userId: Int) async -> AsyncResult<UserProfile> {
    try? await Task.sleep(nanoseconds: 500_000_000)

    if let user = store.users[userId] {
      return .success(user)
    } else {
      return .error(APIErrorMessage(message: "User not found"))
    }
  }

  func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if var user = store.users[userId] {
      user.isFollowing = isFollowing
      store.users[userId] = user
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "User not found"))
    }
  }
}
