import Foundation

final class MockUserRepository: @unchecked Sendable {
  static let shared = MockUserRepository()

  var users: [Int: DetailedUser]

  init() {
    let baseDate = Date()

    self.users = [
      1: DetailedUser(
        userId: 1,
        username: "wesleynw",
        createdAt: baseDate.addingTimeInterval(-31_536_000),
        name: "Wesley Weisenberger",
        bio: """
          welcome to splajompy!\nno, I don't know your password, they're all encrypted and whatever.

          https://splajompy.com
          """,
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: true,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      6: DetailedUser(
        userId: 6,
        username: "wesley",
        createdAt: baseDate.addingTimeInterval(-25_920_000),
        name: "Wesley",
        bio:
          "coffee enthusiast ☕ | sunset photographer 📸 | always up for a good conversation",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      25: DetailedUser(
        userId: 25,
        username: "joel",
        createdAt: baseDate.addingTimeInterval(-20_736_000),
        name: "Joel",
        bio: "heart collector 💕 spreading good vibes everywhere I go",
        isFollower: false,
        isFollowing: true,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      120: DetailedUser(
        userId: 120,
        username: "realsophie",
        createdAt: baseDate.addingTimeInterval(-18_144_000),
        name: "Sophie",
        bio:
          "curious about everything • sunset appreciator • always asking the right questions ✨",
        isFollower: true,
        isFollowing: false,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: ["joel", "wesley"],
        mutualCount: 2,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      103: DetailedUser(
        userId: 103,
        username: "splazackly",
        createdAt: baseDate.addingTimeInterval(-15_552_000),
        name: "Splazackly",
        bio:
          "comment connoisseur 😛 | farmer's market regular | living life one incredible moment at a time",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      112: DetailedUser(
        userId: 112,
        username: "giuseppe",
        createdAt: baseDate.addingTimeInterval(-12_960_000),
        name: "Giuseppe",
        bio:
          "coffee shop discoverer ☕ | post appreciator | finding amazing places in the city",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      97: DetailedUser(
        userId: 97,
        username: "elena",
        createdAt: baseDate.addingTimeInterval(-10_368_000),
        name: "Elena",
        bio:
          "plot twist enthusiast 📺 | thoughtful commenter | always here for a good discussion",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      113: DetailedUser(
        userId: 113,
        username: "pari",
        createdAt: baseDate.addingTimeInterval(-7_776_000),
        name: "Pari",
        bio:
          "new follower alert! 🎉 | community builder | excited to connect with everyone",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        isMuting: false,
        isFriend: false,
        mutuals: [],
        mutualCount: 0,
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
    ]
  }
}

struct MockProfileService: ProfileServiceProtocol {
  func getNotificationActors(notificationId: Int, limit: Int, before: Date?) async -> Result<
    PaginatedUserList, Error
  > {
    return .success(PaginatedUserList(users: [], nextCursor: nil))
  }

  func getFriends(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>
  {
    return .success(PaginatedUserList(users: [], nextCursor: nil))
  }

  private let store = MockUserRepository.shared

  func getProfile(userId: Int) async -> Result<DetailedUser, Error> {
    try? await Task.sleep(nanoseconds: 500_000_000)
    if let user = store.users[userId] {
      return .success(user)
    } else {
      return .failure(APIErrorMessage(message: "User not found"))
    }
  }

  func getUserFromUsernamePrefix(prefix: String) async -> Result<[PublicUser], Error> {
    let baseDate = Date()

    return .success([
      PublicUser(
        userId: 1001,
        username: prefix + "_janesmith",
        createdAt: baseDate.addingTimeInterval(-8_640_000),
        name: "Jane Smith",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      PublicUser(
        userId: 1002,
        username: prefix + "davewilson",
        createdAt: baseDate.addingTimeInterval(-4_320_000),
        name: "David Wilson",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      PublicUser(
        userId: 1003,
        username: prefix + "mariagarcia",
        createdAt: baseDate.addingTimeInterval(-2_160_000),
        name: "Maria Garcia",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
    ])
  }

  func updateProfile(
    name: String,
    bio: String,
    displayProperties: UserDisplayProperties
  ) async
    -> Result<Void, Error>
  {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return .success(())
  }

  func toggleFollowing(userId: Int, isFollowing: Bool) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    if var user = store.users[userId] {
      user.isFollowing = isFollowing
      store.users[userId] = user
      return .success(())
    } else {
      return .failure(APIErrorMessage(message: "User not found"))
    }
  }

  func toggleBlocking(userId: Int, isBlocking: Bool) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    if var user = store.users[userId] {
      user.isBlocking = isBlocking
      store.users[userId] = user
      return .success(())
    } else {
      return .failure(APIErrorMessage(message: "User not found"))
    }
  }

  func toggleMuting(userId: Int, isMuting: Bool) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    if var user = store.users[userId] {
      user.isMuting = isMuting
      store.users[userId] = user
      return .success(())
    } else {
      return .failure(APIErrorMessage(message: "User not found"))
    }
  }

  func requestFeature(text: String) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return .success(())
  }

  func getFollowers(userId: Int, limit: Int, before: Date?) async
    -> Result<[DetailedUser], Error>
  {
    try? await Task.sleep(nanoseconds: 300_000_000)
    let allUsers = Array(store.users.values)

    let paginatedUsers = Array(allUsers).map { profile in
      DetailedUser(
        userId: profile.userId,
        username: profile.username,
        createdAt: profile.createdAt,
        name: profile.name,
        bio: profile.bio,
        isFollower: profile.isFollower,
        isFollowing: profile.isFollowing,
        isBlocking: profile.isBlocking,
        isMuting: profile.isMuting,
        isFriend: profile.isFriend,
        mutuals: profile.mutuals,
        mutualCount: profile.mutuals.count,
        isVerified: profile.isVerified,
        displayProperties: profile.displayProperties
      )
    }
    return .success(paginatedUsers)
  }

  func getFollowing(userId: Int, limit: Int, before: Date?) async -> Result<
    PaginatedUserList, Error
  > {
    try? await Task.sleep(nanoseconds: 300_000_000)
    return .success(PaginatedUserList(users: [], nextCursor: nil))
    //    let users = Array(store.users.values)
    //    return .success(PaginatedUserList(users: users, nextCursor: nil))
  }

  func getMutuals(userId: Int, limit: Int, before: Date?) async -> Result<PaginatedUserList, Error>
  {
    try? await Task.sleep(nanoseconds: 300_000_000)
    let mutualUsers = Array(store.users.values).filter { $0.isFollower && $0.isFollowing }
    return .success(PaginatedUserList(users: mutualUsers, nextCursor: nil))
  }

  func addFriend(userId: Int) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    return .success(())
  }

  func removeFriend(userId: Int) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: 300_000_000)
    return .success(())
  }

  func getAppStatistics() async -> Result<AppStatistics, Error> {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return .success(
      AppStatistics(
        totalPosts: 1234,
        totalComments: 5678,
        totalLikes: 9012,
        totalFollows: 345,
        totalUsers: 89,
        totalNotifications: 456
      )
    )
  }
}
