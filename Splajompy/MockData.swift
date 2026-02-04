import Foundation

struct Mocks {
  static let testUser1 = DetailedUser(
    userId: 1,
    email: "wesleynw@pm.me",
    username: "wesley",
    createdAt: Date(),
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
    createdAt: Date(),
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
    createdAt: Date(),
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

  static let basicUser = User(
    userId: 0,
    email: "wesleynw@pmme",
    username: "Wesley",
    createdAt: Date(),
    name: "test",
    isVerified: false
  )

  static let testPublicUser1 = PublicUser(
    userId: 100,
    username: "wesley",
    createdAt: Date(),
    name: "Wesley W",
    isVerified: true,
    displayProperties: UserDisplayProperties(fontChoiceId: 0)
  )

  static let testPublicUser2 = PublicUser(
    userId: 101,
    username: "bobsmith",
    createdAt: Date(),
    name: nil,
    isVerified: false,
    displayProperties: UserDisplayProperties(fontChoiceId: 1)
  )

  static let post1 = DetailedPost(
    post: Post(
      postId: 2000,
      userId: 1,
      text:
        "check this out: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
      createdAt: Date(),
      facets: nil
    ),
    user: PublicUser(
      userId: 1,
      username: "wesleynw",
      createdAt: Date(),
      name: "Wesley 🌌",
      isVerified: true,
      displayProperties: UserDisplayProperties(fontChoiceId: 0)
    ),
    isLiked: false,
    commentCount: 0,
    images: nil,
    relevantLikes: [],
    hasOtherLikes: false,
    isPinned: false
  )

  static let wrappedData = WrappedData(
    activityData: ActivityOverviewData(
      activityCountCeiling: 1,
      counts: ["test": 5],
      mostActiveDay: "asdf"
    ),
    weeklyActivityData: [
      87,
      77,
      100,
      92,
      78,
      79,
      91,
    ],
    sliceData: SliceData(
      percent: 5,
      postComponent: 1.5,
      commentComponent: 2.0,
      likeComponent: 1.5
    ),
    comparativePostStatisticsData: ComparativePostStatisticsData(
      postLengthVariation: 10.16273846328,
      imageLengthVariation: -5.123
    ),
    mostLikedPost: post1,
    favoriteUsers: [
      FavoriteUserData(user: testPublicUser1, proportion: 100),
      FavoriteUserData(user: testPublicUser2, proportion: 49.554354343534),
      FavoriteUserData(user: testPublicUser1, proportion: 30.1238921738921),
      FavoriteUserData(user: testPublicUser1, proportion: 30.1238921738921),
      FavoriteUserData(user: testPublicUser1, proportion: 30.1238921738921),
    ],
    totalWordCount: 18356,
    controversialPoll: Poll(
      title: "should i add polls?",
      voteTotal: 14,
      currentUserVote: 2,
      options: [
        PollOption(title: "yes 😛", voteTotal: 8),
        PollOption(title: "i thought you’d never ask", voteTotal: 4),
        PollOption(title: "is the sky blue?", voteTotal: 2),
      ]
    ),
    generatedUtc: Date()
  )
}
