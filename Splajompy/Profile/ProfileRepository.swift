import Foundation

struct UpdateProfileRequest: Encodable {
  let name: String
  let bio: String
  let displayProperties: UserDisplayProperties
}

protocol ProfileServiceProtocol: Sendable {
  func getProfile(userId: Int) async -> AsyncResult<DetailedUser>
  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<
    [PublicUser]
  >
  func updateProfile(
    name: String,
    bio: String,
    displayProperties: UserDisplayProperties
  ) async
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

  //  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<
  //    [DetailedUser]
  //  >

  /// Fetch users that the given user is following.
  func getFollowing(userId: Int, limit: Int, before: Date?) async
    -> AsyncResult<PaginatedUserList>

  func getMutuals(userId: Int, limit: Int, before: Date?) async -> AsyncResult<
    PaginatedUserList
  >

  /// Fetch friends of a target user.
  func getFriends(userId: Int, limit: Int, before: Date?) async -> AsyncResult<
    PaginatedUserList
  >

  /// Fetches a list of users who have contributed to a notification.
  func getNotificationActors(notificationId: Int, limit: Int, before: Date?)
    async -> AsyncResult<PaginatedUserList>

  /// Add a user to the current user's friends list.
  func addFriend(userId: Int) async -> AsyncResult<EmptyResponse>

  /// Remove a user from the current user's friends list.
  func removeFriend(userId: Int) async -> AsyncResult<EmptyResponse>

  /// Fetch the current user's push notification preferences.
  func getPushPreferences() async -> AsyncResult<PushPreferences>

  /// Update the current user's push notification preferences.
  func updatePushPreferences(prefs: PushPreferences) async -> AsyncResult<
    EmptyResponse
  >

  /// Fetch statistics about app.
  func getAppStatistics() async -> AsyncResult<AppStatistics>
}

struct ProfileService: ProfileServiceProtocol {
  func getProfile(userId: Int) async -> AsyncResult<DetailedUser> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<
    [PublicUser]
  > {
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
    -> AsyncResult<
      EmptyResponse
    >
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

  func getFollowing(userId: Int, limit: Int, before: Date?) async
    -> AsyncResult<PaginatedUserList>
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

  func getMutuals(userId: Int, limit: Int, before: Date?) async -> AsyncResult<
    PaginatedUserList
  > {
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

  func getFriends(userId: Int, limit: Int, before: Date?) async -> AsyncResult<
    PaginatedUserList
  > {
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
    async -> AsyncResult<PaginatedUserList>
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

  func addFriend(userId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)/friend",
      method: "POST"
    )
  }

  func removeFriend(userId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)/friend",
      method: "DELETE"
    )
  }

  func getPushPreferences() async -> AsyncResult<PushPreferences> {
    return await APIService.performRequest(
      endpoint: "user/push-preferences",
      method: "GET"
    )
  }

  func updatePushPreferences(prefs: PushPreferences) async -> AsyncResult<
    EmptyResponse
  > {
    guard let data = try? JSONEncoder().encode(prefs) else {
      return .error(APIErrorMessage(message: "Failed to encode preferences"))
    }
    return await APIService.performRequest(
      endpoint: "user/push-preferences",
      method: "PATCH",
      body: data
    )
  }

  func getAppStatistics() async -> AsyncResult<AppStatistics> {
    return await APIService.performRequest(
      endpoint: "stats",
      method: "GET"
    )
  }
}
