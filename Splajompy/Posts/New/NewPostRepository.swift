import Foundation
import PhotosUI
import SwiftUI

struct ImageData: Encodable {
  let s3Key: String
  let width: Int
  let height: Int
}

struct CreatePostRequest: Encodable {
  let text: String
  let imageKeymap: [Int: ImageData]  // [displayOrder : ImageData]
  let visibility: Int
  let poll: PollCreationRequest?
}

struct PresignedUrlResponse: Codable {
  let key: String
  let url: String
}

struct PostCreationService {
  enum PostCreationError: Error {
    case imageUploadFailure
  }

  static func createPost(
    text: String,
    images: [PlatformImage],
    visibility: VisibilityType,
    poll: PollCreationRequest? = nil
  ) async -> AsyncResult<EmptyResponse> {
    do {
      guard let imageKeymap = await uploadImages(images: images) else {
        return .error(PostCreationError.imageUploadFailure)
      }

      let createPostRequest = CreatePostRequest(
        text: text,
        imageKeymap: imageKeymap,
        visibility: visibility.id,
        poll: poll
      )
      let jsonData = try JSONEncoder().encode(createPostRequest)

      return await APIService.performRequest(
        endpoint: "v2/post/new",
        method: "POST",
        body: jsonData
      )

    } catch {
      return .error(error)
    }
  }

  static func validatePostText(text: String) -> (
    isValid: Bool, errorMessage: String?
  ) {
    if text.count > 2500 {
      return (false, "This post is \(text.count - 2500) characters too long.")
    }
    return (true, nil)
  }
}
