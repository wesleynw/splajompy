import NukeUI
import SwiftUI

struct NotificationImageView: View {
  let url: String

  private static let targetSize: CGFloat = 40

  var body: some View {
    if let url = URL(string: url) {
      LazyImage(url: url) {
        state in
        if let image = state.image {
          image.resizable()
            .aspectRatio(contentMode: .fill)
        } else {
          ProgressView()
            .frame(maxWidth: Self.targetSize, maxHeight: Self.targetSize)
        }
      }
      .processors([
        .resize(
          size: CGSize(width: Self.targetSize, height: Self.targetSize), unit: .points,
          contentMode: .aspectFill)
      ])
      .frame(width: Self.targetSize, height: Self.targetSize)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}
