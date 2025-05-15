import Foundation

enum FeedType {
  case home
  case all
  case profile
}

protocol PostServiceProtocol: Sendable {
  func getPostById(postId: Int) async -> AsyncResult<DetailedPost>

  func getPostsForFeed(feedType: FeedType, userId: Int?, offset: Int, limit: Int) async
    -> AsyncResult<[DetailedPost]>

  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<EmptyResponse>

  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  >

  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse>
}

struct PostService: PostServiceProtocol {
  private let fetchLimit = 10

  func getPostById(postId: Int) async -> AsyncResult<DetailedPost> {
    return await APIService.performRequest(endpoint: "post/\(postId)")
  }

  func getPostsForFeed(
    feedType: FeedType,
    userId: Int? = nil,
    offset: Int,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]> {
    let urlBase: String
    switch feedType {
    case .home:
      urlBase = "posts/following"
    case .all:
      urlBase = "posts/all"
    case .profile:
      guard let userId = userId else {
        return .error(URLError(.badURL))
      }
      urlBase = "user/\(userId)/posts"
    }

    let queryItems = [
      URLQueryItem(name: "offset", value: "\(offset)"),
      URLQueryItem(name: "limit", value: "\(limit)"),
    ]

    return await APIService.performRequest(
      endpoint: urlBase,
      queryItems: queryItems
    )
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
    return await APIService.performRequest(endpoint: "post/\(postId)", method: "DELETE")
  }
}
