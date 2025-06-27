import Foundation
import PhotosUI
import SwiftUI

struct CreatePostRequest: Encodable {
  let text: String
  let imageKeymap: [Int: String]  // [displayOrder : s3Key]
}

struct PresignedUrlResponse: Codable {
  let key: String
  let url: String
}

struct PostCreationService {
  static func createPost(
    text: String,
    images: [UIImage],
    items: [PhotosPickerItem]
  ) async -> AsyncResult<EmptyResponse> {
    do {
      let stagingFolder = UUID()
      var imageKeymap = [Int: String]()

      for (index, image) in images.enumerated() {
        if let preferredFilenameExtension = items[index].supportedContentTypes
          .first?.preferredFilenameExtension
        {
          let response: AsyncResult<PresignedUrlResponse> =
            await APIService.performRequest(
              endpoint: "post/presignedUrl",
              method: "GET",
              queryItems: [
                URLQueryItem(
                  name: "extension",
                  value: "\(preferredFilenameExtension)"
                ),
                URLQueryItem(
                  name: "folder",
                  value: "\(stagingFolder)"
                ),
              ]
            )

          switch response {
          case .success(let urlResponse):
            if let url = URL(string: urlResponse.url) {
              guard
                let compressedImage = image.jpegData(
                  compressionQuality: 1
                )
              else {
                return .error(
                  NSError(
                    domain: "ImageUploader",
                    code: 1,
                    userInfo: [
                      NSLocalizedDescriptionKey: "Failed to compress image"
                    ]
                  )
                )
              }

              var request = URLRequest(url: url)
              request.httpMethod = "PUT"
              request.setValue(
                "application/octet-stream",
                forHTTPHeaderField: "Content-Type"
              )

              // TODO: this is okay for now, but need to find something safer in the future
              request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")

              let (_, s3Response) = try await URLSession.shared.upload(
                for: request,
                from: compressedImage
              )

              guard let httpResponse = s3Response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
              else {
                return .error(
                  NSError(
                    domain: "ImageUploader",
                    code: 2,
                    userInfo: [
                      NSLocalizedDescriptionKey: "Failed to upload image"
                    ]
                  )
                )
              }

              imageKeymap[index] = urlResponse.key
            }
          case .error:
            return .error(
              NSError(
                domain: "ImageUploader",
                code: 2,
                userInfo: [
                  NSLocalizedDescriptionKey: "Failed to upload image"
                ]
              )
            )
          }
        }
      }

      let createPostRequest = CreatePostRequest(
        text: text,
        imageKeymap: imageKeymap
      )
      let jsonData = try JSONEncoder().encode(createPostRequest)

      return await APIService.performRequest(
        endpoint: "post/new",
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
    if text.count > 5000 {
      return (false, "This post is \(text.count - 5000) characters too long.")
    }
    return (true, nil)
  }
}
