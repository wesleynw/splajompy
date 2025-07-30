import Kingfisher
import NukeUI
import SwiftUI

struct CustomAsyncImage: View {
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

  private var screenWidth: CGFloat {
    #if os(iOS)
      return UIScreen.main.bounds.width
    #else
      return NSScreen.main?.frame.width ?? 400
    #endif
  }

  //  var body: some View {
  //    KFImage(url)
  //      .cacheOriginalImage()
  //      .serialize(as: .PNG)  // store as .png to preserve alpha channel
  //      .downsampling(size: processorSize)
  //      .roundCorner(radius: .point(15))
  //      .placeholder {
  //        ProgressView()
  //      }
  //      .retry(maxCount: 2, interval: .seconds(1))
  //      .resizable()
  //      .aspectRatio(contentMode: contentMode)
  //  }

  var body: some View {
    LazyImage(url: url) {
      state in
      if let image = state.image {
        image.resizable()
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .processors([.resize(width: screenWidth), .roundedCorners(radius: 10)])
    .aspectRatio(contentMode: contentMode)
  }
}

#Preview {
  CustomAsyncImage(
    URL(
      string:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"
    )
  )
  .frame(height: 200)
}
