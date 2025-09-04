import Foundation

struct Comment: Identifiable, Decodable {
  let commentId: Int
  let postId: Int
  let userId: Int
  let text: String
  let createdAt: String

  var id: Int { commentId }
}

struct DetailedComment: Identifiable, Decodable, Equatable {
  let commentId: Int
  let postId: Int
  let userId: Int
  let text: String
  let createdAt: String
  let user: User
  let facets: [Facet]?
  var isLiked: Bool

  var id: Int { commentId }

  static func == (lhs: DetailedComment, rhs: DetailedComment) -> Bool {
    return lhs.commentId == rhs.commentId
  }
}

protocol CommentServiceProtocol: Sendable {
  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]>

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> AsyncResult<EmptyResponse>

  func addComment(postId: Int, text: String) async -> AsyncResult<
    DetailedComment
  >

  func deleteComment(commentId: Int) async -> AsyncResult<EmptyResponse>
}

struct CommentService: CommentServiceProtocol {
  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]> {
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

  func addComment(postId: Int, text: String) async -> AsyncResult<
    DetailedComment
  > {
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

  func deleteComment(commentId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "comment/\(commentId)",
      method: "DELETE"
    )
  }
}
