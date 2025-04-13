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

struct ProfileService {
  static func getUserProfile(userId: Int) async -> AsyncResult<UserProfile> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  static func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<EmptyResponse> {
    let method = isFollowing ? "DELETE" : "POST"

    return await APIService.performRequest(
      endpoint: "follow/\(userId)",
      method: method
    )
  }
}
