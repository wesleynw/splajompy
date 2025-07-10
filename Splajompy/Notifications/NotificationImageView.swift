import Kingfisher
import SwiftUI

struct NotificationImageView: View {
  let url: String
  let width: Int32
  let height: Int32

  private static let targetSize: CGFloat = 40

  private static var scale: CGFloat {
    #if os(iOS)
      return UIScreen.main.scale
    #else
      return NSScreen.main?.backingScaleFactor ?? 1.0
    #endif
  }

  private static var targetPixelSize: CGFloat {
    return targetSize * scale
  }

  private var aspectRatio: CGFloat {
    CGFloat(width) / CGFloat(height)
  }

  private var processorSize: CGSize {
    aspectRatio > 1
      ? CGSize(
        width: Self.targetPixelSize * aspectRatio,
        height: Self.targetPixelSize
      )
      : CGSize(
        width: Self.targetPixelSize,
        height: Self.targetPixelSize / aspectRatio
      )
  }

  var body: some View {
    KFImage(URL(string: url))
      .placeholder {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: Self.targetSize, height: Self.targetSize)
      }
      .setProcessor(DownsamplingImageProcessor(size: processorSize))
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: Self.targetSize, height: Self.targetSize)
      .clipped()
      .cornerRadius(5)
  }
}
