import Foundation

func uploadImages(images: [PlatformImage]) async throws -> [Int: ImageData] {
  let stagingFolder = UUID()
  var imageKeymap = [Int: ImageData]()

  for (index, image) in images.enumerated() {
    let response: AsyncResult<PresignedUrlResponse> =
      // TODO: add expiry for staged items
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
            value: "\(stagingFolder)"
          ),
        ]
      )

    switch response {
    case .success(let urlResponse):
      guard let url = URL(string: urlResponse.url) else {
        print("[uploadImages] Invalid presigned URL string: \(urlResponse.url)")
        throw PostCreationService.PostCreationError.invalidPresignedUrl(urlResponse.url)
      }
      guard let compressedImage = image.jpegData(compressionQuality: 1) else {
        print("[uploadImages] Failed to compress image at index \(index) to JPEG")
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
          print("[uploadImages] S3 upload rejected for image \(index): HTTP \(statusCode)")
          throw PostCreationService.PostCreationError.s3UploadFailed(statusCode: statusCode)
        }

        let imageSize = image.uploadSize

        imageKeymap[index] = ImageData(
          s3Key: urlResponse.key,
          width: Int(imageSize.width),
          height: Int(imageSize.height)
        )
      } catch let error as PostCreationService.PostCreationError {
        throw error
      } catch {
        print("[uploadImages] S3 upload network error for image \(index): \(error)")
        throw PostCreationService.PostCreationError.s3UploadError(error)
      }
    case .error(let error):
      print("[uploadImages] Presigned URL request failed for image \(index): \(error)")
      throw PostCreationService.PostCreationError.presignedUrlRequestFailed
    }
  }

  return imageKeymap
}
