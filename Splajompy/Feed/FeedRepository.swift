import Foundation

enum FeedType {
  case home
  case all
  case profile
}

struct FeedService {
  private let fetchLimit = 10

  static func getFeedPosts(
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

  static func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isLiked ? "DELETE" : "POST"

    return await APIService.performRequest(
      endpoint: "post/\(postId)/liked",
      method: method
    )
  }

  static func addComment(postId: Int, content: String) async -> AsyncResult<
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
}
