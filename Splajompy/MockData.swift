import Foundation

struct Mocks {
  private nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let testUser1 = DetailedUser(
    userId: 1,
    email: "wesleynw@pm.me",
    username: "wesley",
    createdAt: formatter.string(from: Date()),
    name: "Wesley Weisenberger",
    bio: "iOS Developer",
    isFollower: false,
    isFollowing: true,
    isBlocking: false,
    isMuting: false,
    mutuals: ["alice", "bob"],
    mutualCount: 2,
    isVerified: false,
    displayProperties: UserDisplayProperties(fontChoiceId: 0)
  )

  static let testUser2 = DetailedUser(
    userId: 2,
    email: "john@example.com",
    username: "johndoe",
    createdAt: formatter.string(from: Date()),
    name: "John Doe",
    bio: "iOS Developer",
    isFollower: true,
    isFollowing: true,
    isBlocking: false,
    isMuting: false,
    mutuals: ["alice", "bob", "wesley"],
    mutualCount: 3,
    isVerified: false,
    displayProperties: UserDisplayProperties(fontChoiceId: 1)
  )

  static let testUser3 = DetailedUser(
    userId: 3,
    email: "john@example.com",
    username: "johndoe",
    createdAt: formatter.string(from: Date()),
    name: nil,
    bio: "iOS Developer",
    isFollower: true,
    isFollowing: true,
    isBlocking: false,
    isMuting: false,
    mutuals: ["alice", "bob", "wesley"],
    mutualCount: 3,
    isVerified: false,
    displayProperties: UserDisplayProperties(fontChoiceId: 2)
  )

  static let wrappedData = WrappedData(
    activityData: ActivityOverviewData(
      activityCountCeiling: 1,
      counts: ["test": 5],
      mostActiveDay: "asdf"
    ),
    sliceData: SliceData(
      percent: 5,
      postComponent: 1.5,
      commentComponent: 2.0,
      likeComponent: 1.5
    ),
    comparativePostStatisticsData: ComparativePostStatisticsData(
      postLengthVariation: 10.16273846328,
      imageLengthVariation: -5.123
    )
  )
}
