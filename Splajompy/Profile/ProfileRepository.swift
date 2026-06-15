import Foundation

struct UpdateProfileRequest: Encodable {
  let name: String
  let bio: String
  let displayProperties: UserDisplayProperties
}

protocol ProfileServiceProtocol: Sendable {
  func getProfile(userId: Int) async -> Result<DetailedUser, Error>
  func getUserFromUsernamePrefix(prefix: String) async -> Result<[PublicUser], Error>
  func updateProfile(
    name: String,
    bio: String,
    displayProperties: UserDisplayProperties
  ) async
    -> Result<Void, Error>
  func toggleFollowing(userId: Int, isFollowing: Bool) async -> Result<Void, Error>
  func toggleBlocking(userId: Int, isBlocking: Bool) async -> Result<Void, Error>
  func toggleMuting(userId: Int, isMuting: Bool) async -> Result<Void, Error>
  func requestFeature(text: String) async -> Result<Void, Error>

  /// Fetch users that the given user is following.
  func getFollowing(userId: Int, limit: Int, before: Date?) async
    -> Result<PaginatedUserList, Error>

  func getMutuals(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>

  /// Fetch friends of a target user.
  func getFriends(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>

  /// Fetches a list of users who have contributed to a notification.
  func getNotificationActors(notificationId: Int, limit: Int, before: Date?)
    async -> Result<PaginatedUserList, Error>

  /// Add a user to the current user's friends list.
  func addFriend(userId: Int) async -> Result<Void, Error>

  /// Remove a user from the current user's friends list.
  func removeFriend(userId: Int) async -> Result<Void, Error>

  /// Fetch statistics about app.
  func getAppStatistics() async -> Result<AppStatistics, Error>
}

struct ProfileService: ProfileServiceProtocol {
  func getProfile(userId: Int) async -> Result<DetailedUser, Error> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  func getUserFromUsernamePrefix(prefix: String) async -> Result<[PublicUser], Error> {
    let queryItems = [URLQueryItem(name: "prefix", value: "\(prefix)")]
    return await APIService.performRequest(
      endpoint: "users/search",
      queryItems: queryItems
    )
  }

  func updateProfile(
    name: String,
    bio: String,
    displayProperties: UserDisplayProperties
  ) async
    -> Result<Void, Error>
  {
    let request = UpdateProfileRequest(
      name: name,
      bio: bio,
      displayProperties: displayProperties
    )
    let requestData: Data
    do {
      requestData = try JSONEncoder().encode(request)
    } catch {
      return .failure(error)
    }
    return await APIService.performRequest(
      endpoint: "user/profile",
      method: "POST",
      body: requestData
    )
  }

  func toggleFollowing(userId: Int, isFollowing: Bool) async -> Result<Void, Error> {
    let method = isFollowing ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "follow/\(userId)",
      method: method
    )
  }

  func toggleBlocking(userId: Int, isBlocking: Bool) async -> Result<Void, Error> {
    let method = isBlocking ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "user/\(userId)/block",
      method: method
    )
  }

  func toggleMuting(userId: Int, isMuting: Bool) async -> Result<Void, Error> {
    let method = isMuting ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "user/\(userId)/mute",
      method: method
    )
  }

  func requestFeature(text: String) async -> Result<Void, Error> {
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

  func getFollowing(userId: Int, limit: Int, before: Date?) async
    -> Result<PaginatedUserList, Error>
  {
    var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let before = before {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(name: "before", value: formatter.string(from: before))
      )
    }
    return await APIService.performRequest(
      endpoint: "v3/user/\(userId)/following",
      queryItems: queryItems
    )
  }

  func getMutuals(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>
  {
    var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let before = before {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(name: "before", value: formatter.string(from: before))
      )
    }
    return await APIService.performRequest(
      endpoint: "v3/user/\(userId)/mutuals",
      queryItems: queryItems
    )
  }

  func getFriends(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>
  {
    var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let before = before {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(name: "before", value: formatter.string(from: before))
      )
    }
    return await APIService.performRequest(
      endpoint: "v2/user/friends",
      queryItems: queryItems
    )
  }

  func getNotificationActors(notificationId: Int, limit: Int, before: Date?)
    async -> Result<PaginatedUserList, Error>
  {
    var queryItems = [
      URLQueryItem(name: "limit", value: "\(limit)")
    ]

    if let before = before {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(name: "before", value: formatter.string(from: before))
      )
    }

    return await APIService.performRequest(
      endpoint: "users/notification/\(notificationId)",
      queryItems: queryItems
    )
  }

  func addFriend(userId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)/friend",
      method: "POST"
    )
  }

  func removeFriend(userId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)/friend",
      method: "DELETE"
    )
  }

  func getAppStatistics() async -> Result<AppStatistics, Error> {
    return await APIService.performRequest(
      endpoint: "stats",
      method: "GET"
    )
  }
}
