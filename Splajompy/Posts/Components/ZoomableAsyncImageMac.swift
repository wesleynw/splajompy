import NukeUI
import SwiftUI

struct ZoomableAsyncImageMac: View {
  let imageUrl: String

  @State private var scale: CGFloat = 1.0

  var body: some View {
    GeometryReader { proxy in
      NukeUI.LazyImage(url: URL(string: imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
              TapGesture(count: 2)
                .onEnded {
                  if scale == 1 {
                    scale = 2
                  } else {
                    scale = 1
                  }
                }
            )
            .gesture(
              MagnificationGesture()
                .onChanged { value in
                  scale = value
                }
            )
        } else if state.error != nil {
          Color.red  // error placeholder
        } else {
          ProgressView()
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}

#Preview {
  ZoomableAsyncImageMac(
    imageUrl:
      "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"
  )
}
