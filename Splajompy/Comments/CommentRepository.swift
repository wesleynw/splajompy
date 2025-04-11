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

struct CommentService {
  static func getComments(postId: Int) async -> APIResult<[Comment]> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comments",
      method: "GET"
    )
  }

  static func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> APIResult<Void>
  {
    let method = isLiked ? "DELETE" : "POST"

    let result: APIResult<EmptyResponse> = await APIService.performRequest(
      endpoint: "post/\(postId)/comment/\(commentId)/liked",
      method: method
    )

    switch result {
    case .success:
      return .success(())
    case .failure(let error):
      return .failure(error)
    }
  }

  static func addComment(postId: Int, text: String) async -> APIResult<Comment> {
    do {
      let bodyData: [String: String] = ["Text": text]
      let jsonData = try JSONEncoder().encode(bodyData)

      return await APIService.performRequest(
        endpoint: "post/\(postId)/comment",
        method: "POST",
        body: jsonData
      )
    } catch {
      return .failure(error)
    }
  }
}
