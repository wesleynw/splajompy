import Foundation

enum PhotoState: Equatable {
  case loading(Progress)
  case success(PlatformImage)
  case failure
  case empty
}

enum UploadState: Equatable {
  case pending
  case uploaded(ImageData)
  case failed
}

func uploadImage(
  _ image: PlatformImage,
  folder: UUID
) async throws -> ImageData {
  let response: Result<PresignedUrlResponse, Error> =
    await APIService.performRequest(
      endpoint: "post/presignedUrl",
      method: "GET",
      queryItems: [
        URLQueryItem(
          name: "extension",
          value: "jpg"
        ),
        URLQueryItem(
          name: "folder",
          value: "\(folder)"
        ),
      ]
    )

  switch response {
  case .success(let urlResponse):
    guard let url = URL(string: urlResponse.url) else {
      print("[uploadImage] Invalid presigned URL string: \(urlResponse.url)")
      throw PostCreationService.PostCreationError.invalidPresignedUrl(urlResponse.url)
    }
    let resizedImage = image.resized(toWidth: 2048)
    guard let compressedImage = resizedImage.jpegData(compressionQuality: 0.85) else {
      print("[uploadImage] Failed to compress image to JPEG")
      throw PostCreationService.PostCreationError.imageCompressionFailed
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue(
      "application/octet-stream",
      forHTTPHeaderField: "Content-Type"
    )

    do {
      let (_, s3Response) = try await URLSession.shared.upload(
        for: request,
        from: compressedImage
      )

      guard let httpResponse = s3Response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      else {
        let statusCode = (s3Response as? HTTPURLResponse)?.statusCode ?? -1
        print("[uploadImage] S3 upload rejected: HTTP \(statusCode)")
        throw PostCreationService.PostCreationError.s3UploadFailed(statusCode: statusCode)
      }

      let imageSize = resizedImage.uploadSize

      return ImageData(
        s3Key: urlResponse.key,
        width: Int(imageSize.width),
        height: Int(imageSize.height)
      )
    } catch let error as PostCreationService.PostCreationError {
      throw error
    } catch {
      print("[uploadImage] S3 upload network error: \(error)")
      throw PostCreationService.PostCreationError.s3UploadError(error)
    }
  case .failure(let error):
    print("[uploadImage] Presigned URL request failed: \(error)")
    throw PostCreationService.PostCreationError.presignedUrlRequestFailed
  }
}

func uploadImageState(_ image: PlatformImage, folder: UUID) async -> UploadState {
  do {
    let imageData = try await uploadImage(image, folder: folder)
    return .uploaded(imageData)
  } catch {
    return .failed
  }
}
