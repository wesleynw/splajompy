import Foundation

//struct DetailedUser: Decodable {
//  let userId: Int
//  let email: String
//  let username: String
//  let createdAt: String
//  var name: String
//  var bio: String
//  var isFollower: Bool
//  var isFollowing: Bool
//  var isBlocking: Bool
//  var isMuting: Bool
//  let mutuals: [String]
//  let mutualCount: Int
//  var isVerified: Bool?
//}

struct UpdateProfileRequest: Encodable {
  let name: String
  let bio: String
  let displayProperties: UserDisplayProperties
}

protocol ProfileServiceProtocol: Sendable {
  func getProfile(userId: Int) async -> AsyncResult<DetailedUser>
  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<[PublicUser]>
  func updateProfile(name: String, bio: String, displayProperties: UserDisplayProperties) async
    -> AsyncResult<
      EmptyResponse
    >
  func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func toggleBlocking(userId: Int, isBlocking: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func toggleMuting(userId: Int, isMuting: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func requestFeature(text: String) async -> AsyncResult<EmptyResponse>
  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  >
  func getFollowing(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  >
  func getMutuals(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  >
  func getAppStats() async -> AsyncResult<AppStats>
}

struct ProfileService: ProfileServiceProtocol {
  func getProfile(userId: Int) async -> AsyncResult<DetailedUser> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<[PublicUser]> {
    let queryItems = [URLQueryItem(name: "prefix", value: "\(prefix)")]
    return await APIService.performRequest(
      endpoint: "users/search",
      queryItems: queryItems
    )
  }

  func updateProfile(name: String, bio: String, displayProperties: UserDisplayProperties) async
    -> AsyncResult<
      EmptyResponse
    >
  {
    let request = UpdateProfileRequest(name: name, bio: bio, displayProperties: displayProperties)
    let requestData: Data
    do {
      requestData = try JSONEncoder().encode(request)
    } catch {
      return .error(error)
    }
    return await APIService.performRequest(
      endpoint: "user/profile",
      method: "POST",
      body: requestData
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

  func toggleBlocking(userId: Int, isBlocking: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isBlocking ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "user/\(userId)/block",
      method: method
    )
  }

  func toggleMuting(userId: Int, isMuting: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isMuting ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "user/\(userId)/mute",
      method: method
    )
  }

  func requestFeature(text: String) async -> AsyncResult<EmptyResponse> {
    struct Container: Codable {
      let text: String
    }

    let container = Container(text: text)
    let jsonData = try! JSONEncoder().encode(container)

    return await APIService.performRequest(
      endpoint: "request-feature",
      method: "POST",
      queryItems: nil,
      body: jsonData
    )
  }

  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  > {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]
    return await APIService.performRequest(
      endpoint: "user/\(userId)/followers",
      queryItems: queryItems
    )
  }

  func getFollowing(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  > {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]
    return await APIService.performRequest(
      endpoint: "user/\(userId)/following",
      queryItems: queryItems
    )
  }

  func getMutuals(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
    [DetailedUser]
  > {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]
    return await APIService.performRequest(
      endpoint: "user/\(userId)/mutuals",
      queryItems: queryItems
    )
  }

  func getAppStats() async -> AsyncResult<AppStats> {
    return await APIService.performRequest(
      endpoint: "stats",
      method: "GET"
    )
  }
}
