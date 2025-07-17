import Kingfisher
import SwiftUI

struct OptimizedKFImage: View {
  let url: URL?
  let contentMode: SwiftUI.ContentMode
  let targetSize: CGSize

  init(
    _ url: URL?,
    contentMode: SwiftUI.ContentMode = .fit,
    targetSize: CGSize = CGSize(width: 400, height: 400)
  ) {
    self.url = url
    self.contentMode = contentMode
    self.targetSize = targetSize
  }

  private var scale: CGFloat {
    #if os(iOS)
      return UIScreen.main.scale
    #else
      return NSScreen.main?.backingScaleFactor ?? 1.0
    #endif
  }

  private var processorSize: CGSize {
    CGSize(
      width: min(targetSize.width * scale, 1000),
      height: min(targetSize.height * scale, 1000)
    )
  }

  var body: some View {
    KFImage(url)
      .cacheOriginalImage()
      .serialize(as: .PNG)  // store as .png to preserve alpha channel
      .downsampling(size: processorSize)
      .roundCorner(radius: .point(15))
      .placeholder {
        ProgressView()
      }
      .retry(maxCount: 2, interval: .seconds(1))
      .resizable()
      .aspectRatio(contentMode: contentMode)
  }
}

#Preview {
  OptimizedKFImage(
    URL(
      string:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"
    )
  )
  .frame(height: 200)
}
