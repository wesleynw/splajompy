import Foundation

struct Comment: Identifiable, Decodable {
  let commentId: Int
  let postId: Int
  let userId: Int
  let text: String
  let createdAt: String

  var id: Int { commentId }
}

struct CreateCommentRequest: Encodable {
  let text: String
  let imageKeymap: [Int: ImageData]
}

protocol CommentServiceProtocol: Sendable {
  func getComments(postId: Int) async -> Result<[DetailedComment], Error>

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> Result<Void, Error>

  func addComment(postId: Int, text: String, image: PlatformImage?) async
    -> Result<DetailedComment, Error>

  func deleteComment(commentId: Int) async -> Result<Void, Error>
}

struct CommentService: CommentServiceProtocol {
  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comments",
      method: "GET"
    )
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> Result<Void, Error>
  {
    let method = isLiked ? "DELETE" : "POST"

    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment/\(commentId)/liked",
      method: method
    )
  }

  func addComment(postId: Int, text: String, image: PlatformImage?) async
    -> Result<DetailedComment, Error>
  {
    var imageKeymap: [Int: ImageData] = [:]
    if let image {
      do {
        imageKeymap = try await uploadImages(images: [image])
      } catch {
        return .failure(error)
      }
    }

    let body = CreateCommentRequest(text: text, imageKeymap: imageKeymap)

    let jsonData: Data
    do {
      jsonData = try JSONEncoder().encode(body)
    } catch {
      return .failure(error)
    }

    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment",
      method: "POST",
      body: jsonData
    )
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    return await APIService.performRequest(
      endpoint: "comment/\(commentId)",
      method: "DELETE"
    )
  }
}
