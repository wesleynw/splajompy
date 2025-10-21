import Foundation

enum FeedType: String, CaseIterable {
  case home
  case all
  case profile
  case mutual
  case following
}

protocol PostServiceProtocol: Sendable {
  func getPostById(postId: Int) async -> AsyncResult<DetailedPost>
  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int?,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]>
  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  >
  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse>
  func reportPost(postId: Int) async -> AsyncResult<EmptyResponse>
  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> AsyncResult<
    EmptyResponse
  >
  func pinPost(postId: Int) async -> AsyncResult<EmptyResponse>
  func unpinPost() async -> AsyncResult<EmptyResponse>
}

struct PostService: PostServiceProtocol {
  private let fetchLimit = 10

  func getPostById(postId: Int) async -> AsyncResult<DetailedPost> {
    return await APIService.performRequest(endpoint: "post/\(postId)")
  }

  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int? = nil,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]> {
    let urlBase: String
    switch feedType {
    case .home:
      urlBase = "v2/posts/following"
    case .all:
      urlBase = "v2/posts/all"
    case .profile:
      guard let userId = userId else {
        return .error(URLError(.badURL))
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

    let result: AsyncResult<[DetailedPost]> = await APIService.performRequest(
      endpoint: urlBase,
      queryItems: queryItems
    )

    return result
  }

  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isLiked ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "post/\(postId)/liked",
      method: method
    )
  }

  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  > {
    let bodyData: [String: String] = ["Text": content]
    let jsonData: Data
    do {
      jsonData = try JSONEncoder().encode(bodyData)
    } catch {
      return .error(error)
    }
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment",
      method: "POST",
      body: jsonData
    )
  }

  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)",
      method: "DELETE"
    )
  }

  func reportPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/report",
      method: "POST"
    )
  }

  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> AsyncResult<
    EmptyResponse
  > {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/vote/\(optionIndex)",
      method: "POST"
    )
  }

  func pinPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "posts/\(postId)/pin",
      method: "POST"
    )
  }

  func unpinPost() async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "posts/pin",
      method: "DELETE"
    )
  }
}
