import Foundation

struct UserDisplayProperties: Codable {
  let fontChoiceId: Int?
}

struct User: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: Date
  let name: String?
  var isFollowing: Bool?
  let isVerified: Bool?
}

struct PublicUser: Decodable, Identifiable {
  let userId: Int
  let username: String
  let createdAt: Date
  let name: String?
  let isVerified: Bool
  let displayProperties: UserDisplayProperties?
  let isFriend: Bool?

  var id: Int { userId }

  init(
    userId: Int,
    username: String,
    createdAt: Date,
    name: String?,
    isVerified: Bool,
    displayProperties: UserDisplayProperties,
    isFriend: Bool? = nil
  ) {
    self.userId = userId
    self.username = username
    self.createdAt = createdAt
    self.name = name
    self.isVerified = isVerified
    self.displayProperties = displayProperties
    self.isFriend = isFriend
  }

  init(from detailedUser: DetailedUser) {
    self.userId = detailedUser.userId
    self.username = detailedUser.username
    self.createdAt = detailedUser.createdAt
    self.name = detailedUser.name
    self.isVerified = detailedUser.isVerified
    self.displayProperties = detailedUser.displayProperties
    self.isFriend = detailedUser.isFriend
  }
}

struct DetailedUser: Decodable, Identifiable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: Date
  var name: String?
  var bio: String
  var isFollower: Bool
  var isFollowing: Bool
  var isBlocking: Bool
  var isMuting: Bool
  var isFriend: Bool
  let mutuals: [String]
  let mutualCount: Int
  let isVerified: Bool
  var displayProperties: UserDisplayProperties

  var id: Int { userId }
}

struct ImageDTO: Decodable {
  let imageId: Int
  let postId: Int
  let height: Int
  let width: Int
  let imageBlobUrl: String
  let displayOrder: Int
}

struct Facet: Decodable {
  let type: String
  let userId: Int
  let indexStart: Int
  let indexEnd: Int
}

// For sane string replacement when inserting mentions, sort facets such that facets that occur at the end of the post text are processed first.
extension Facet: Comparable {
  static func < (lhs: Facet, rhs: Facet) -> Bool {
    return lhs.indexStart > rhs.indexStart
  }
}

struct Post: Decodable {
  let postId: Int
  let userId: Int
  let text: String?
  let createdAt: Date
  let facets: [Facet]?
  var visibility: VisibilityType = .everyone

  var richContent: AttributedString? {
    guard let text, !text.isEmpty else { return nil }

    // TODO: the null coalescing here is dumb
    let markdown = generateAttributedStringUsingFacets(
      text,
      facets: self.facets ?? []
    )

    return try! AttributedString(
      markdown: markdown,
      options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
      )
    )
  }
}

struct RelevantLike: Decodable {
  let username: String
  let userId: Int
}

struct DetailedPost: Decodable, Equatable, Identifiable {
  var post: Post
  var user: PublicUser
  var isLiked: Bool
  var commentCount: Int
  var images: [ImageDTO]?
  var relevantLikes: [RelevantLike]
  var hasOtherLikes: Bool
  var poll: Poll?
  var isPinned: Bool

  var id: Int { post.postId }

  static func == (lhs: DetailedPost, rhs: DetailedPost) -> Bool {
    return lhs.post.postId == rhs.post.postId
  }
}

struct PollCreationRequest: Encodable {
  let title: String
  let options: [String]
}

struct Poll: Decodable {
  let title: String
  var voteTotal: Int
  var currentUserVote: Int?
  var options: [PollOption]
}

struct PollOption: Decodable {
  let title: String
  var voteTotal: Int
}

struct AppStatistics: Decodable {
  let totalPosts: Int
  let totalComments: Int
  let totalLikes: Int
  let totalFollows: Int
  let totalUsers: Int
  let totalNotifications: Int
}

enum VisibilityType: Int, Decodable, Identifiable, CaseIterable {
  case everyone = 0
  case friends = 1

  var id: Int { rawValue }
}
