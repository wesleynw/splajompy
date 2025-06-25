import SwiftUI

struct ZoomableAsyncImage: View {
  let url: URL
  let imageID: String
  let namespace: Namespace.ID
  let onTap: () -> Void

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  init(url: URL, imageID: String, namespace: Namespace.ID, onTap: @escaping () -> Void) {
    self.url = url
    self.imageID = imageID
    self.namespace = namespace
    self.onTap = onTap
  }

  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .empty:
        ProgressView()
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
          .matchedGeometryEffect(id: imageID, in: namespace)
          .scaleEffect(scale)
          .offset(offset)
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 5.0)
              }
              .onEnded { _ in
                lastScale = 1.0
                if scale < 1.2 {
                  withAnimation {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                  }
                }
              }
          )
          .simultaneousGesture(
            DragGesture()
              .onChanged { value in
                if scale > 1.0 {
                  offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                  )
                }
              }
              .onEnded { _ in
                lastOffset = offset
              }
          )
          .simultaneousGesture(
            TapGesture(count: 2).onEnded {
              withAnimation {
                if scale > 1.0 {
                  scale = 1.0
                  offset = .zero
                  lastOffset = .zero
                } else {
                  scale = 3.0
                }
              }
            }
          )
          .simultaneousGesture(
            TapGesture().onEnded {
              if scale <= 1.0 {
                onTap()
              }
            }
          )
      case .failure:
        Image(systemName: "photo")
          .font(.largeTitle)
          .foregroundColor(.white)
          .matchedGeometryEffect(id: imageID, in: namespace)
          .onTapGesture {
            onTap()
          }
      @unknown default:
        EmptyView()
      }
    }
  }
}
