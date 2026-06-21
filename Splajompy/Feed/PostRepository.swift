import Foundation

enum FeedType: String, CaseIterable, Identifiable {
  case all
  case profile
  case mutual
  case following

  var id: String { rawValue }
}

protocol PostServiceProtocol: Sendable {
  func getPostById(postId: Int) async -> Result<DetailedPost, Error>
  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int?,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> Result<[DetailedPost], Error>
  func toggleLike(postId: Int, isLiked: Bool) async -> Result<Void, Error>
  func addComment(postId: Int, content: String) async -> Result<Void, Error>
  func deletePost(postId: Int) async -> Result<Void, Error>
  func reportPost(postId: Int) async -> Result<Void, Error>
  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> Result<
    Void, Error
  >
  func pinPost(postId: Int) async -> Result<Void, Error>
  func unpinPost() async -> Result<Void, Error>
}

struct PostService: PostServiceProtocol {
  private let fetchLimit = 10

  func getPostById(postId: Int) async -> Result<DetailedPost, Error> {
    return await APIService.performRequest(endpoint: "post/\(postId)")
  }

  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int? = nil,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> Result<[DetailedPost], Error> {
    let urlBase: String
    switch feedType {
    case .all:
      urlBase = "v2/posts/all"
    case .profile:
      guard let userId = userId else {
        return .failure(URLError(.badURL))
      }
      urlBase = "v2/user/\(userId)/posts"
    case .mutual:
      urlBase = "v2/posts/mutual"
    case .following:
      urlBase = "v2/posts/following"
    }

    var queryItems = [
      URLQueryItem(name: "limit", value: "\(limit)")
    ]

    if let beforeTimestamp = beforeTimestamp {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(
          name: "before",
          value: formatter.string(from: beforeTimestamp)
        )
      )
    }

    let result: Result<[DetailedPost], Error> = await APIService.performRequest(
      endpoint: urlBase,
      queryItems: queryItems
    )

    return result
  }

  func toggleLike(postId: Int, isLiked: Bool) async -> Result<Void, Error> {
    let method = isLiked ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "post/\(postId)/liked",
      method: method
    )
  }

  func addComment(postId: Int, content: String) async -> Result<Void, Error> {
    let bodyData: [String: String] = ["Text": content]
    let jsonData: Data
    do {
      jsonData = try JSONEncoder().encode(bodyData)
    } catch {
      return .failure(error)
    }
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment",
      method: "POST",
      body: jsonData
    )
  }

  func deletePost(postId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)",
      method: "DELETE"
    )
  }

  func reportPost(postId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/report",
      method: "POST"
    )
  }

  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> Result<
    Void, Error
  > {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/vote/\(optionIndex)",
      method: "POST"
    )
  }

  func pinPost(postId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "posts/\(postId)/pin",
      method: "POST"
    )
  }

  func unpinPost() async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "posts/pin",
      method: "DELETE"
    )
  }
}
