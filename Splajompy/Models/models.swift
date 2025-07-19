import Foundation

struct User: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: Date
  let name: String?
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
  let post: Post
  let user: User
  var isLiked: Bool
  var commentCount: Int
  var images: [ImageDTO]?
  let relevantLikes: [RelevantLike]
  let hasOtherLikes: Bool
  var poll: Poll?

  var id: Int { post.postId }

  static func == (lhs: DetailedPost, rhs: DetailedPost) -> Bool {
    return lhs.post.postId == rhs.post.postId
  }
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
