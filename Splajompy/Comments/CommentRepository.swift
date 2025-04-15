import Foundation

struct Comment: Identifiable, Decodable {
  let commentId: Int
  let postId: Int
  let userId: Int
  let text: String
  let createdAt: String
  let user: User
  var isLiked: Bool

  var id: Int { commentId }
}

protocol CommentServiceProtocol: Sendable {
  func getComments(postId: Int) async -> AsyncResult<[Comment]>

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> AsyncResult<EmptyResponse>

  func addComment(postId: Int, text: String) async -> AsyncResult<Comment>
}

struct CommentService: CommentServiceProtocol {
  func getComments(postId: Int) async -> AsyncResult<[Comment]> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comments",
      method: "GET"
    )
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> AsyncResult<EmptyResponse>
  {
    let method = isLiked ? "DELETE" : "POST"

    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment/\(commentId)/liked",
      method: method
    )
  }

  func addComment(postId: Int, text: String) async -> AsyncResult<Comment> {
    let bodyData: [String: String] = ["Text": text]
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
