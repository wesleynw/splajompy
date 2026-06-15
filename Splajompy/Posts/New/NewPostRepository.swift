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
  enum PostCreationError: Error, LocalizedError {
    case presignedUrlRequestFailed
    case invalidPresignedUrl(String)
    case imageCompressionFailed
    case s3UploadFailed(statusCode: Int)
    case s3UploadError(any Error)

    var errorDescription: String? {
      switch self {
      case .presignedUrlRequestFailed:
        return "Failed to get upload URL from server."
      case .invalidPresignedUrl(let url):
        return "Server returned an invalid upload URL: \(url)"
      case .imageCompressionFailed:
        return "Failed to compress image for upload."
      case .s3UploadFailed(let statusCode):
        return "Image upload was rejected by storage (HTTP \(statusCode))."
      case .s3UploadError(let error):
        return "Image upload failed: \(error.localizedDescription)"
      }
    }
  }

  static func createPost(
    text: String,
    images: [PlatformImage],
    visibility: VisibilityType,
    poll: PollCreationRequest? = nil
  ) async -> Result<Void, Error> {
    do {
      let imageKeymap = try await uploadImages(images: images)

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
      return .failure(error)
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
