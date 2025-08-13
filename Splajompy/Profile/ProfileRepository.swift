import Foundation

struct UserProfile: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: String
  var name: String
  var bio: String
  var isFollower: Bool
  var isFollowing: Bool
  var isBlocking: Bool
  let mutuals: [String]
}

struct UpdateProfileRequest: Encodable {
  let name: String
  let bio: String
}

protocol ProfileServiceProtocol: Sendable {
  func getProfile(userId: Int) async -> AsyncResult<UserProfile>
  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<[User]>
  func updateProfile(name: String, bio: String) async -> AsyncResult<
    EmptyResponse
  >
  func toggleFollowing(userId: Int, isFollowing: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func toggleBlocking(userId: Int, isBlocking: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func requestFeature(text: String) async -> AsyncResult<EmptyResponse>
  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]>
  func getFollowing(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]>
}

struct ProfileService: ProfileServiceProtocol {
  func getProfile(userId: Int) async -> AsyncResult<UserProfile> {
    return await APIService.performRequest(
      endpoint: "user/\(userId)",
      method: "GET"
    )
  }

  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<[User]> {
    let queryItems = [URLQueryItem(name: "prefix", value: "\(prefix)")]
    return await APIService.performRequest(
      endpoint: "users/search",
      queryItems: queryItems
    )
  }

  func updateProfile(name: String, bio: String) async -> AsyncResult<
    EmptyResponse
  > {
    let request = UpdateProfileRequest(name: name, bio: bio)
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

  func requestFeature(text: String) async -> AsyncResult<EmptyResponse> {
    struct Container: Codable {
      let text: String
    }

    let container = Container(text: text)
    let jsonData = try! JSONEncoder().encode(container)

    return await APIService.performRequest(
      endpoint: "request-feature", method: "POST", queryItems: nil, body: jsonData)
  }

  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]> {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)")
    ]
    return await APIService.performRequest(
      endpoint: "user/\(userId)/followers",
      queryItems: queryItems
    )
  }

  func getFollowing(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]> {
    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)")
    ]
    return await APIService.performRequest(
      endpoint: "user/\(userId)/following",
      queryItems: queryItems
    )
  }
}

final class MockUserStore: @unchecked Sendable {
  static let shared = MockUserStore()

  private let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  var users: [Int: UserProfile]

  init() {
    let baseDate = Date()

    self.users = [
      1: UserProfile(
        userId: 1,
        email: "wesleynw@pm.me",
        username: "wesleynw",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-31_536_000)
        ),
        name: "Wesley 🌌",
        bio:
          "splajompy creator",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        mutuals: []
      ),
      6: UserProfile(
        userId: 6,
        email: "wesley@example.com",
        username: "wesley",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-25_920_000)
        ),
        name: "Wesley",
        bio:
          "coffee enthusiast ☕ | sunset photographer 📸 | always up for a good conversation",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      ),
      25: UserProfile(
        userId: 25,
        email: "joel@example.com",
        username: "joel",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-20_736_000)
        ),
        name: "Joel",
        bio: "heart collector 💕 spreading good vibes everywhere I go",
        isFollower: false,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      ),
      120: UserProfile(
        userId: 120,
        email: "sophie@example.com",
        username: "realsophie",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-18_144_000)
        ),
        name: "Sophie",
        bio:
          "curious about everything • sunset appreciator • always asking the right questions ✨",
        isFollower: true,
        isFollowing: false,
        isBlocking: false,
        mutuals: ["joel", "wesley"]
      ),
      103: UserProfile(
        userId: 103,
        email: "splazackly@example.com",
        username: "splazackly",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-15_552_000)
        ),
        name: "Splazackly",
        bio:
          "comment connoisseur 😛 | farmer's market regular | living life one incredible moment at a time",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      ),
      112: UserProfile(
        userId: 112,
        email: "giuseppe@example.com",
        username: "giuseppe",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-12_960_000)
        ),
        name: "Giuseppe",
        bio:
          "coffee shop discoverer ☕ | post appreciator | finding amazing places in the city",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        mutuals: []
      ),
      97: UserProfile(
        userId: 97,
        email: "elena@example.com",
        username: "elena",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-10_368_000)
        ),
        name: "Elena",
        bio:
          "plot twist enthusiast 📺 | thoughtful commenter | always here for a good discussion",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      ),
      113: UserProfile(
        userId: 113,
        email: "pari@example.com",
        username: "pari",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-7_776_000)
        ),
        name: "Pari",
        bio:
          "new follower alert! 🎉 | community builder | excited to connect with everyone",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        mutuals: []
      ),
      30: UserProfile(
        userId: 30,
        email: "showrunner@example.com",
        username: "showrunner",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-5_184_000)
        ),
        name: "The Showrunner",
        bio:
          "season finale specialist 📺 | creating conversations about the stories we love",
        isFollower: false,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      ),
      15: UserProfile(
        userId: 15,
        email: "marketvendor@example.com",
        username: "marketvendor",
        createdAt: formatter.string(
          from: baseDate.addingTimeInterval(-2_592_000)
        ),
        name: "Market Maven",
        bio:
          "weekend farmer's market haul curator 🥕 | fresh produce enthusiast | feeding the community",
        isFollower: true,
        isFollowing: false,
        isBlocking: false,
        mutuals: []
      ),
    ]
  }
}

struct MockProfileService: ProfileServiceProtocol {
  private let store = MockUserStore.shared

  func getProfile(userId: Int) async -> AsyncResult<UserProfile> {
    try? await Task.sleep(nanoseconds: 500_000_000)
    if let user = store.users[userId] {
      return .success(user)
    } else {
      return .error(APIErrorMessage(message: "User not found"))
    }
  }

  func getUserFromUsernamePrefix(prefix: String) async -> AsyncResult<[User]> {
    let baseDate = Date()

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    return .success([
      User(
        userId: 1001,
        email: "jane.smith@example.com",
        username: prefix + "_janesmith",
        createdAt: baseDate.addingTimeInterval(-8_640_000),
        name: "Jane Smith"
      ),
      User(
        userId: 1002,
        email: "david.wilson@example.com",
        username: prefix + "davewilson",
        createdAt: baseDate.addingTimeInterval(-4_320_000),
        name: "David Wilson"
      ),
      User(
        userId: 1003,
        email: "maria.garcia@example.com",
        username: prefix + "mariagarcia",
        createdAt: baseDate.addingTimeInterval(-2_160_000),
        name: "Maria Garcia"
      ),
    ])
  }

  func updateProfile(name: String, bio: String) async -> AsyncResult<
    EmptyResponse
  > {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return .success(EmptyResponse())
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

  func toggleBlocking(userId: Int, isBlocking: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    try? await Task.sleep(nanoseconds: 300_000_000)
    if var user = store.users[userId] {
      user.isBlocking = isBlocking
      store.users[userId] = user
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "User not found"))
    }
  }

  func requestFeature(text: String) async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return .success(EmptyResponse())
  }

  func getFollowers(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    let allUsers = Array(store.users.values)
    let startIndex = min(offset, allUsers.count)
    let endIndex = min(offset + limit, allUsers.count)
    
    let paginatedUsers = Array(allUsers[startIndex..<endIndex]).map { profile in
      DetailedUser(
        userId: profile.userId,
        email: profile.email,
        username: profile.username,
        createdAt: Date(),
        name: profile.name,
        bio: profile.bio,
        isFollower: profile.isFollower,
        isFollowing: profile.isFollowing,
        isBlocking: profile.isBlocking,
        mutuals: profile.mutuals
      )
    }
    return .success(paginatedUsers)
  }

  func getFollowing(userId: Int, offset: Int, limit: Int) async -> AsyncResult<[DetailedUser]> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    let allUsers = Array(store.users.values)
    let startIndex = min(offset, allUsers.count)
    let endIndex = min(offset + limit, allUsers.count)
    
    let paginatedUsers = Array(allUsers[startIndex..<endIndex]).map { profile in
      DetailedUser(
        userId: profile.userId,
        email: profile.email,
        username: profile.username,
        createdAt: Date(),
        name: profile.name,
        bio: profile.bio,
        isFollower: profile.isFollower,
        isFollowing: profile.isFollowing,
        isBlocking: profile.isBlocking,
        mutuals: profile.mutuals
      )
    }
    return .success(paginatedUsers)
  }
}
