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
    isVerified: false
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
    isVerified: false
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
    isVerified: false
  )
}
