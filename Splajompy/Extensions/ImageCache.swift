import Foundation
import Nuke

/// Initializes an image cache
func initializeImageCache() {
  var cacheConfig = ImagePipeline.Configuration.withDataCache(
    name: "media-cache",
    sizeLimit: 500 * 1024 * 1024  // 500MB
  )
  cacheConfig.dataCachePolicy = .storeEncodedImages  // cache processed images
  ImagePipeline.shared = ImagePipeline(
    configuration: cacheConfig,
    delegate: ImagePipelineCustomDelegate()
  )
}

final class ImagePipelineCustomDelegate: ImagePipeline.Delegate {
  /// cacheKey strips s3 presigning params from URL, which change on every reload
  func cacheKey(for request: ImageRequest, pipeline: ImagePipeline) -> String? {
    guard let url = request.url,
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }
    components.query = nil
    let baseKey = components.url?.absoluteString ?? ""
    let processorIds = request.processors.map(\.identifier).joined(separator: ",")
    guard !processorIds.isEmpty else { return baseKey }
    return "\(baseKey)|\(processorIds)"
  }
}
