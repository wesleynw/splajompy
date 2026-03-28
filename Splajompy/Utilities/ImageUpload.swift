import Foundation

func uploadImages(images: [PlatformImage]) async -> [Int: ImageData]? {
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
        return nil
      }
      guard let compressedImage = image.jpegData(compressionQuality: 1) else {
        return nil
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
          return nil
        }

        let imageSize = image.uploadSize

        imageKeymap[index] = ImageData(
          s3Key: urlResponse.key,
          width: Int(imageSize.width),
          height: Int(imageSize.height)
        )
      } catch {
        return nil
      }
    case .error:
      return nil
    }
  }

  return imageKeymap
}
