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
  
  var body: some View {
    KFImage(url)
      .setProcessor(
        DownsamplingImageProcessor(
          size: CGSize(
            width: min(targetSize.width * UIScreen.main.scale, 800),
            height: min(targetSize.height * UIScreen.main.scale, 800)
          )
        )
      )
      .fade(duration: 0.15)
      .placeholder {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
      }
      .retry(maxCount: 2, interval: .seconds(1))
      .resizable()
      .aspectRatio(contentMode: contentMode)
  }
}

#Preview {
  OptimizedKFImage(
    URL(string: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg")
  )
  .frame(height: 200)
} 
